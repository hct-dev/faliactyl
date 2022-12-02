/**
 * FALIACTYL DASHBOARD
 *
 * @package    FALIACTYL
 * @author     Hydra Cloud LLC and Zircon Dev
 * @copyright  Copyright (c) Hydra Cloud LLC
 * @license    https://hct.digital/apps/faliactyl/eula Faliactyl Eula
 */
var _$_7221=["\x73\x65\x74\x74\x69\x6E\x67\x73","\x2E\x2E\x2F\x68\x61\x6E\x64\x6C\x65\x72\x73\x2F\x72\x65\x61\x64\x53\x65\x74\x74\x69\x6E\x67\x73","\x2E\x2E\x2F\x68\x61\x6E\x64\x6C\x65\x72\x73\x2F\x64\x61\x74\x61\x62\x61\x73\x65","\x6E\x6F\x64\x65\x2D\x66\x65\x74\x63\x68","\x65\x78\x70\x6F\x72\x74\x73","\x67\x65\x74","\x6A\x73\x6F\x6E","\x6B\x65\x79","\x41\x6E\x74\x69\x56\x50\x4E","\x6C\x6F\x67","\x70\x72\x6F\x78\x79","\x73\x65\x74","\x79\x65\x73"];const settings=require(_$_7221[1])[_$_7221[0]]();const db=require(_$_7221[2]);const fetch=require(_$_7221[3]);module[_$_7221[4]]= (_0xBB93)=>{return  new Promise(async (_0xBBAE)=>{let _0xBBC9= await db[_$_7221[5]](`vpninfo-${_0xBB93}`);if(!_0xBBC9){try{vpncheck= await( await fetch(`https://proxycheck.io/v2/${_0xBB93}?key=${settings[_$_7221[8]][_$_7221[7]]}&vpn=1`))[_$_7221[6]]()}catch(err){console[_$_7221[9]](err)}};if(_0xBBC9|| (vpncheck&& vpncheck[_0xBB93])){if(!_0xBBC9){_0xBBC9= vpncheck[_0xBB93][_$_7221[10]]}; await db[_$_7221[11]](`vpninfo-${_0xBB93}`,_0xBBC9);if(_0xBBC9=== _$_7221[12]){return _0xBBAE(true)}else {return _0xBBAE(false)}}else {return _0xBBAE(false)}})}