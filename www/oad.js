/*
        Copyright 2013-2014, QingYue Technology

        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

                http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
*/


var exec = require('cordova/exec');

var OadManager = function(device){
    this.device = device;
    this.imgVersion = '0xFFFF';
    this.curImgType = null;
};

/*
 *
 */
var oad = {
    imageNotifyUUID: 'f000ffc1-0451-4000-b000-000000000000',

    imageBlockRequestUUID: 'f000ffc2-0451-4000-b000-000000000000',

    imageNotification: '00002902-0000-1000-8000-00805f9b34fb',

    detectImage: function(device, callback, errorFunc){
	var oadservice = new OadManager(device);
	var me = this;
	console.log(me);
	var notifyChar = device.__uuidMap[me.imageNotifyUUID];
	if(notifyChar){
	    // Set humidity notification to ON.
	    device.writeDescriptor(
		me.imageNotifyUUID,
		me.imageNotification, // Notification descriptor.
		new Uint8Array([1, 0]),
		function()
		{
		    console.log('Status: writeDescriptor ok.');
		},
		function(errorCode)
		{
		    // This error will happen on iOS, since this descriptor is not
		    // listed when requesting descriptors. On iOS you are not allowed
		    // to use the configuration descriptor explicitly. It should be
		    // safe to ignore this error.
		    console.log('Error: writeDescriptor: ' + errorCode + '.');
		});

	    device.enableNotification(
		me.imageNotifyUUID,
		function(data){
		    console.log("notifiy data : ");
		    console.log(data.getHexString());
		    console.log(oadservice);
		    if(oadservice.imgVersion == '0xFFFF'){
			var imgHdr = new Uint16Array(data);
			var imgType = imgHdr[0] & 0x01 ? 'B' : 'A';
			oadservice.curImgType = imgType;
			oadservice.imgVersion = data.getHexString();
			console.log(oadservice);
			callback(oadservice);
		    }
		},
		function(errorCode){
		    console.log('Error: enableNotification: ' + errorCode + '.');
		}
	    );

	    device.writeCharacteristic(
	    	me.imageNotifyUUID,
	    	new Uint8Array([0]),
	    	function(data)
	    	{
	    	    console.log('Status: writeCharacteristic 0 ok.');
	    	    console.log(data);
	    	},
	    	function(errorCode)
	    	{
	    	    console.log('Error: writeCharacteristic: ' + errorCode + '.');
	    	});

	    device.writeCharacteristic(
		me.imageNotifyUUID,
		new Uint8Array([1]),
		function(data)
		{
		    console.log('Status: writeCharacteristic 1 ok.');
		    console.log(data);
		},
		function(errorCode)
		{
		    console.log('Error: writeCharacteristic: ' + errorCode + '.');
		});
	    
	}else{
	    if(errorFunc){
		errorFunc();
	    }
	}
    },
    
    uploadImage : function(oadservice, filename, callback, errorFunc){
	// if(oadservice.curImgType == null)
        //     return;
	// var imgType = 'A';
        // if(oadservice.curImgType == 'A')
        //     imgType = 'B';
        var me = this;
	console.log("execute uploadImage action");
	console.log(oadservice);
	cordova.exec(function(data){
	    if(data.constructor == ArrayBuffer){
                var writeValue = data.getHexString();
		//console.log(writeValue + " | " + data.byteLength);
                if(data.byteLength == 12){
		    oadservice.device.writeCharacteristic(
			me.imageNotifyUUID,
			new Uint8Array(data),
			function()
			{
			    //console.log('Status: writeCharacteristic notify ok.');
			},
			function(errorCode)
			{
			    console.log('Error: writeCharacteristic: ' + errorCode + '.');
			});
                }
                else{
		    oadservice.device.writeCharacteristic(
			me.imageBlockRequestUUID,
			new Uint8Array(data),
			function()
			{
			    //console.log('Status: writeCharacteristic block ok.');
			},
			function(errorCode)
			{
			    console.log('Error: writeCharacteristic: ' + errorCode + '.');
			});
                };
            }else{
		// console.log(data);
                // show progress by data.secondsLeft
                callback(data);
            };
	}, function(error){
	    errorFunc(error);
	}, "BCOad", "uploadImage", [{"filename": filename}]);
        //cordova.exec(callback, errorFunc, "BCOad", "uploadImage", [{"filename": filename}]);
    },

    validateImage : function(filename, callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "validateImage", [{"filename": filename}]);
    },

    getFWFiles : function(callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "getFWFiles", []);
    },

    setImageType: function(imgType, callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "setImageType", [{'imgType': imgType}]);
    },

    addEventListener : function(eventName, callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "addEventListener", [{"eventName": eventName}]);
    }
};

ArrayBuffer.prototype.getHexString = function(){
    var length = this.byteLength;
    var dv = new DataView(this);
    var result = "";
    for (var i= 0; i < length; i++) {
        if(dv.getUint8(i) < 16){
            result += '0' + dv.getUint8(i).toString(16);
        }else{
            result += dv.getUint8(i).toString(16);
        }
    }
    return result;
};

module.exports = oad;

