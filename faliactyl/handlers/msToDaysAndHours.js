/**
 * FALIACTYL DASHBOARD
 *
 * @package    FALIACTYL
 * @author     Hydra Cloud LLC and Zircon Dev
 * @copyright  Copyright (c) Hydra Cloud LLC
 * @license    https://hct.digital/apps/faliactyl/eula Faliactyl Eula
 */
var _$_8291=["\x65\x78\x70\x6F\x72\x74\x73","\x66\x6C\x6F\x6F\x72","\x72\x6F\x75\x6E\x64"];module[_$_8291[0]]= msToDaysAndHours();function msToDaysAndHours(_0xBBC9){const _0xBBE4=86400000;const _0xBBFF=3600000;const _0xBB93=Math[_$_8291[1]](_0xBBC9/ _0xBBE4);const _0xBBAE=Math[_$_8291[2]]((_0xBBC9- (_0xBB93* _0xBBE4))/ _0xBBFF* 100)/ 100;let _0xBC1A=`s`;if(_0xBB93=== 1){_0xBC1A= ``};let _0xBC35=`s`;if(_0xBBAE=== 1){_0xBC35= ``};return `${_0xBB93} day${_0xBC1A} and ${_0xBBAE} hour${_0xBC35}`}