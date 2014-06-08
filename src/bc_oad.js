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

    function isEmpty(s){
        return ((s == undefined || s == null || s == "") ? true : false);
    }

    document.addEventListener('bccoreready', onBCCoreReady, false);

    function onBCCoreReady(){
        var eventName = "org.qingyue.oad.ready";
        var OadManager = BC.OadManager = new BC.OadManager("org.qingyue.oad", eventName);
        BC.bluetooth.dispatchEvent(eventName);
    }

    var OadManager = BC.OadManager = BC.Plugin.extend({

        pluginInitialize : function(){

            if(API == "ios"){

            }
        },
    });

    var OadService = BC.OadService = BC.Service.extend({

        serviceUUID: '0xF000FFC0-0451-4000-B000-000000000000',

        imageNotifyUUID: '0xF000FFC1-0451-4000-B000-000000000000',

        imageBlockRequestUUID: '0xF000FFC2-0451-4000-B000-000000000000',

        configureProfile: function(){
            successFunc = successFunc || this.writeSuccess;
            errorFunc = errorFunc || this.writeError;
            writeType = writeType || 'hex';
            writeValue = '0x00';
            this.discoverCharacteristics(function(){
                this.getCharacteristicByUUID(this.imageNotifyUUID)[0].subscribe(functio(){ console.log('notify image')});
                this.getCharacteristicByUUID(this.imageNotifyUUID)[0].write(writeType, writeValue, successFunc, errorFunc);
            });
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

    var UploadImage = BC.OadManager.UploadImage = function(success, error, filename){
        navigator.oad.uploadImage(success, error, filename);
    };

    var ValidateImage = BC.OadManager.ValidateImage = function(success, error, filename){
        navigator.oad.validateImage(success, error, filename);
    };

    var GetFWFiles = BC.OadManager.GetFWFiles = function(success, error){
        navigator.oad.getFWFiles(success, error);
    };

})();