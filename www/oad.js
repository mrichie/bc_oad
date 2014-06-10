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
var platform = require('cordova/platform');
var interval_index = null;

/*
 *
 */
var oad = {

    uploadImage : function(callback, errorFunc, filename){
        cordova.exec(callback, errorFunc, "BCOad", "uploadImage", [{"filename": filename}]);
    },

    validateImage : function(callback, errorFunc, filename){
        cordova.exec(callback, errorFunc, "BCOad", "validateImage", [{"filename": filename}]);
    },

    getFWFiles : function(callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "getFWFiles", []);
    },

    setImageType: function(callback, errorFunc, imgType){
        cordova.exec(callback, errorFunc, "BCOad", "setImageType", [{'imgType': imgType}]);
    },

    addEventListener : function(eventName, callback, errorFunc){
        cordova.exec(callback, errorFunc, "BCOad", "addEventListener", [{"eventName": eventName}]);
    },
};
module.exports = oad;

