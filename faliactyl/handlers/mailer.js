/**
 * FALIACTYL DASHBOARD
 *
 * @package    FALIACTYL
 * @author     Hydra Cloud LLC and Zircon Dev
 * @copyright  Copyright (c) Hydra Cloud LLC
 * @license    https://hct.digital/apps/faliactyl/eula Faliactyl Eula
 */
var _$_7de2=["\x75\x73\x65\x20\x73\x74\x72\x69\x63\x74","\x6E\x6F\x64\x65\x6D\x61\x69\x6C\x65\x72","\x73\x65\x74\x74\x69\x6E\x67\x73","\x2E\x2E\x2F\x68\x61\x6E\x64\x6C\x65\x72\x73\x2F\x72\x65\x61\x64\x53\x65\x74\x74\x69\x6E\x67\x73","\x65\x78\x70\x6F\x72\x74\x73","\x68\x6F\x73\x74","\x73\x6D\x74\x70","\x70\x6F\x72\x74","\x75\x73\x65\x72\x6E\x61\x6D\x65","\x70\x61\x73\x73\x77\x6F\x72\x64","\x63\x72\x65\x61\x74\x65\x54\x72\x61\x6E\x73\x70\x6F\x72\x74"];_$_7de2[0];const nodemailer=require(_$_7de2[1]);const settings=require(_$_7de2[3])[_$_7de2[2]]();module[_$_7de2[4]]= {mailer:()=>{return mailer}};const mailer=nodemailer[_$_7de2[10]]({host:settings[_$_7de2[6]][_$_7de2[5]],port:settings[_$_7de2[6]][_$_7de2[7]],secure:true,auth:{user:settings[_$_7de2[6]][_$_7de2[8]],pass:settings[_$_7de2[6]][_$_7de2[9]]}})