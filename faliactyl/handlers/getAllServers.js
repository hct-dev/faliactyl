/**
 * FALIACTYL DASHBOARD
 *
 * @package    FALIACTYL
 * @author     Hydra Cloud LLC and Zircon Dev
 * @copyright  Copyright (c) Hydra Cloud LLC
 * @license    https://hct.digital/apps/faliactyl/eula Faliactyl Eula
 */
var _$_5112=["\x73\x65\x74\x74\x69\x6E\x67\x73","\x2E\x2F\x72\x65\x61\x64\x53\x65\x74\x74\x69\x6E\x67\x73","\x6E\x6F\x64\x65\x2D\x66\x65\x74\x63\x68","\x65\x78\x70\x6F\x72\x74\x73","\x64\x6F\x6D\x61\x69\x6E","\x70\x74\x65\x72\x6F\x64\x61\x63\x74\x79\x6C","\x6B\x65\x79","\x6A\x73\x6F\x6E"];const settings=require(_$_5112[1])[_$_5112[0]]();const fetch=require(_$_5112[2]);module[_$_5112[3]]= async ()=>{const _0xBB93= await fetch(`${settings[_$_5112[5]][_$_5112[4]]}/api/application/servers?per_page=99999999`,{headers:{"\x41\x75\x74\x68\x6F\x72\x69\x7A\x61\x74\x69\x6F\x6E":`Bearer ${settings[_$_5112[5]][_$_5112[6]]}`}});return  await _0xBB93[_$_5112[7]]()}