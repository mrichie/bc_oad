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
(function(){

    document.addEventListener('bccoreready', onBCCoreReady, false);

    function onBCCoreReady(){
        var eventName = "org.qingyue.oad.ready";
        var oadManager = BC.oadManager = new BC.OadManager("org.qingyue.oad", eventName);
        BC.bluetooth.dispatchEvent(eventName);
    }

    var OadManager = BC.OadManager = BC.Plugin.extend({

        serviceUUID: 'f000ffc0-0451-4000-b000-000000000000',

        pluginInitialize : function(){
            BC.bluetooth.UUIDMap[this.serviceUUID] = BC.OadService;
            this.curImgType = null;
        },

        uploadImage: function(imgType){
            BC.OadManager.UploadImage(function(data){
                if(data.constructor == ArrayBuffer){
                    var dataView = new DataView(data);
                    writeValue = "0x" + dataView.getUint16(1).toString(16).toUpperCase();
                    console.log("writeValue: " + writeValue);
                    // this.getCharacteristicByUUID(
                    //     this.imageNotifyUUID)[0].write('hex',
                    //                                    writeValue,
                    //                                    function(){},
                    //                                    function(){});
                }else{
                    // show progress by data.secondsLeft
                };
            }, function(msg){
                console.log(msg);
            }, 'Image' + imgType + '.bin');
        }

    });

    var UploadImage = BC.OadManager.UploadImage = function(success, error, filename){
        navigator.oad.uploadImage(success, error, filename);
    };

    var ValidateImage = BC.OadManager.ValidateImage = function(success, error, filename){
        navigator.oad.validateImage(success, error, filename);
    };

    var SetImageType = BC.OadManager.SetImageType = function(success, error, imgType){
        navigator.oad.setImageType(success, error, imgType);
    };

    var GetFWFiles = BC.OadManager.GetFWFiles = function(success, error){
        navigator.oad.getFWFiles(success, error);
    };

    var OadService = BC.OadService = BC.Service.extend({

        serviceUUID: 'F000FFC0-0451-4000-B000-000000000000',

        imageNotifyUUID: 'F000FFC1-0451-4000-B000-000000000000',

        imageBlockRequestUUID: 'F000FFC2-0451-4000-B000-000000000000',

        configureProfile: function(){
            successFunc = this.writeSuccess;
            errorFunc = this.writeError;
            writeType = 'hex';
            writeValue = '0x00';
            // 0a00007c41414141
            // 0b00007c42424242
            console.log(this.imageNotifyUUID);
            this.getCharacteristicByUUID(this.imageNotifyUUID)[0].subscribe(function(data){
                console.log(data.value.getHexString());
                BC.OadManager.data = data.value;
                imgHdr = new Uint16Array(data.value.value);
                console.log(imgHdr);
                imgType = imgHdr[0] & 0x01 ? 'B' : 'A';
                console.log(imgType);
                BC.OadManager.curImgType = imgType;
                BC.OadManager.SetImageType(function(msg){console.log(msg)}, null, data.value.getHexString());
            });

            this.getCharacteristicByUUID(this.imageNotifyUUID)[0].write(writeType,
                                                                        writeValue,
                                                                        successFunc,
                                                                        errorFunc);

        },

        deconfigureProfile: function(){

        },

        writeSuccess : function(){
            console.log('writeSuccess');
        },

        writeError : function(){
            console.log('writeFailed');
        },

    });


})();