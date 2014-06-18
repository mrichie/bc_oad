package org.qingyue.oad;

import org.bcsphere.bluetooth.tools.Tools;
import org.qingyue.oad.utils.Conversion;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import android.os.Bundle;
import android.os.Environment;
import android.util.Log;

public class BCOad extends CordovaPlugin {

    public final static String EXTRA_MESSAGE = "org.qingyue.bcoad.MESSAGE";
    // Log
    private static String TAG = "FwUpdateActivity";

    // Activity
    private static final int FILE_ACTIVITY_REQ = 0;

    // Programming parameters
    private static final short OAD_CONN_INTERVAL = 10; // 12.5 msec
    private static final short OAD_SUPERVISION_TIMEOUT = 100; // 1 second
    private static final int PKT_INTERVAL = 20; // Milliseconds
    private static final int GATT_WRITE_TIMEOUT = 100; // Milliseconds

    private static final int FILE_BUFFER_SIZE = 0x40000;
    private static final String FW_CUSTOM_DIRECTORY = Environment.DIRECTORY_DOWNLOADS;
    private static final String FW_FILE_A = "SensorTagImgA.bin";
    private static final String FW_FILE_B = "SensorTagImgB.bin";

    private static final int OAD_BLOCK_SIZE = 16;
    private static final int HAL_FLASH_WORD_SIZE = 4;
    private static final int OAD_BUFFER_SIZE = 2 + OAD_BLOCK_SIZE;
    private static final int OAD_IMG_HDR_SIZE = 8;

    // Programming
    private final byte[] mFileBuffer = new byte[FILE_BUFFER_SIZE];
    private final byte[] mOadBuffer = new byte[OAD_BUFFER_SIZE];
    private ImgHdr mFileImgHdr = new ImgHdr();
    private ImgHdr mTargImgHdr = new ImgHdr();
    private Timer mTimer = null;
    private ProgInfo mProgInfo = new ProgInfo();
    private TimerTask mTimerTask = null;

    // Housekeeping
    private boolean mServiceOk = false;
    private boolean mProgramming = false;
    private int mEstDuration = 0;

    public BCOad() {
    }

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {

    }

    public void setImageType(JSONArray json, CallbackContext callbackContext){
        String paramsKey = "imgType";
        String hexstring = Tools.getData(json, paramsKey);
        byte [] value = new byte[12];
        Conversion.hexStringtoByte(hexstring, value);
        mTargImgHdr.ver = Conversion.buildUint16(value[1], value[0]);
        mTargImgHdr.imgType = ((mTargImgHdr.ver & 1) == 1) ? 'B' : 'A';
        mTargImgHdr.len = Conversion.buildUint16(value[3], value[2]);

        JSONObject obj = new JSONObject();
        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK , obj);
        pluginResult.setKeepCallback(true);
        callbackContext.sendPluginResult(pluginResult);
    }

    public void uploadImage(JSONArray json, CallbackContext callbackContext){
        mProgramming = true;

        // Prepare image notification
        byte[] buf = new byte[OAD_IMG_HDR_SIZE + 2 + 2];
        buf[0] = Conversion.loUint16(mFileImgHdr.ver);
        buf[1] = Conversion.hiUint16(mFileImgHdr.ver);
        buf[2] = Conversion.loUint16(mFileImgHdr.len);
        buf[3] = Conversion.hiUint16(mFileImgHdr.len);
        System.arraycopy(mFileImgHdr.uid, 0, buf, 4, 4);

        // Send image notification
        //mCharIdentify.setValue(buf);
        //mLeService.writeCharacteristic(mCharIdentify);
        JSONObject obj = new JSONObject();
        // transfer buf
        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK , obj);
        pluginResult.setKeepCallback(true);
        callbackContext.sendPluginResult(pluginResult);

        // Initialize stats
        mProgInfo.reset();

        // Start the packet timer
        mTimer = null;
        mTimer = new Timer();
        mTimerTask = new ProgTimerTask(callbackContext);
        mTimer.scheduleAtFixedRate(mTimerTask, 0, PKT_INTERVAL);
    }

    private void onBlockTimer(CallbackContext callbackContext) {

        if (mProgInfo.iBlocks < mProgInfo.nBlocks) {
            mProgramming = true;

            // Prepare block
            mOadBuffer[0] = Conversion.loUint16(mProgInfo.iBlocks);
            mOadBuffer[1] = Conversion.hiUint16(mProgInfo.iBlocks);
            System.arraycopy(mFileBuffer, mProgInfo.iBytes, mOadBuffer, 2, OAD_BLOCK_SIZE);

            // Send block
            //mCharBlock.setValue(mOadBuffer);
            //boolean success = mLeService.writeCharacteristic(mCharBlock);
            boolean success = true;
            JSONObject obj = new JSONObject();
            // transfer mOadBuffer
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK , obj);
            pluginResult.setKeepCallback(true);
            callbackContext.sendPluginResult(pluginResult);

            if (success) {
                // Update stats
                mProgInfo.iBlocks++;
                mProgInfo.iBytes += OAD_BLOCK_SIZE;
            } else {
                // Check if the device has been prematurely disconnected
                //if (BluetoothLeService.getBtGatt() == null)
                //    mProgramming = false;
            }
        } else {
            mProgramming = false;
        }
        mProgInfo.iTimeElapsed += PKT_INTERVAL;

        if (!mProgramming) {
            // runOnUiThread(new Runnable() {
            //         public void run() {
            //             displayStats();
            //             stopProgramming();
            //         }
            //     });
        }
    }

    private void stopProgramming() {
        mTimer.cancel();
        mTimer.purge();
        mTimerTask.cancel();
        mTimerTask = null;

        mProgramming = false;

        if (mProgInfo.iBlocks == mProgInfo.nBlocks) {
            Log.i(TAG, "Programming complete!\n");
        } else {
            Log.i(TAG, "Programming cancelled\n");
        }
    }

    private void displayStats() {
        String txt;
        int byteRate;
        int sec = mProgInfo.iTimeElapsed / 1000;
        if (sec > 0) {
            byteRate = mProgInfo.iBytes / sec;
        } else {
            byteRate = 0;
        }

        txt = String.format("Time: %d / %d sec", sec, mEstDuration);
        txt += String.format("    Bytes: %d (%d/sec)", mProgInfo.iBytes, byteRate);
        Log.i(TAG, txt);
    }

    private class ProgTimerTask extends TimerTask {
        protected CallbackContext cmd;

        public ProgTimerTask(CallbackContext command) {
            this.cmd = command;
        }

        @Override
        public void run() {
            mProgInfo.mTick++;
            if (mProgramming) {
                onBlockTimer(cmd);
                if ((mProgInfo.mTick % PKT_INTERVAL) == 0) {
                    // runOnUiThread(new Runnable() {
                    //         public void run() {
                    //             displayStats();
                    //         }
                    //     });
                }
            }
        }
    }

    private class ImgHdr {
        short ver;
        short len;
        Character imgType;
        byte[] uid = new byte[4];
    }

    private class ProgInfo {
        int iBytes = 0; // Number of bytes programmed
        short iBlocks = 0; // Number of blocks programmed
        short nBlocks = 0; // Total number of blocks
        int iTimeElapsed = 0; // Time elapsed in milliseconds
        int mTick = 0;

        void reset() {
            iBytes = 0;
            iBlocks = 0;
            iTimeElapsed = 0;
            mTick = 0;
            nBlocks = (short) (mFileImgHdr.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE));
        }
    }
}
