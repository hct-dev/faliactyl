/**
 * FALIACTYL DASHBOARD
 *
 * @package    FALIACTYL
 * @author     Hydra Cloud LLC and Zircon Dev
 * @copyright  Copyright (c) Hydra Cloud LLC
 * @license    https://hct.digital/apps/faliactyl/eula Faliactyl Eula
 */

var _$_d38c=["\x2E\x2E\x2F\x69\x6E\x64\x65\x78\x2E\x6A\x73","\x65\x6A\x73","\x65\x78\x70\x72\x65\x73\x73","\x73\x65\x74\x74\x69\x6E\x67\x73","\x2E\x2E\x2F\x68\x61\x6E\x64\x6C\x65\x72\x73\x2F\x72\x65\x61\x64\x53\x65\x74\x74\x69\x6E\x67\x73","\x6E\x6F\x64\x65\x2D\x66\x65\x74\x63\x68","\x63\x68\x61\x6C\x6B","\x2E\x2E\x2F\x68\x61\x6E\x64\x6C\x65\x72\x73\x2F\x64\x61\x74\x61\x62\x61\x73\x65"];const indexjs=require(_$_d38c[0]);const ejs=require(_$_d38c[1]);const express=require(_$_d38c[2]);const settings=require(_$_d38c[4])[_$_d38c[3]]();const fetch=require(_$_d38c[5]);const chalk=require(_$_d38c[6]);const db=require(_$_d38c[7])

module.exports.load = async function(app, ejs, olddb) {
  app.all("/", async (req, res) => {
    if (req.session.pterodactyl) if (req.session.pterodactyl.id !== await db.get("users-" + req.session.userinfo.id)) return res.redirect("/")
    let theme = indexjs.get(req);
    if (theme.settings.mustbeloggedin.includes(req._parsedUrl.pathname)) if (!req.session.userinfo || !req.session.pterodactyl) return res.redirect("/");
    if (theme.settings.mustbeadmin.includes(req._parsedUrl.pathname)) {
      ejs.renderFile(
        `./themes/${theme.name}/${theme.settings.notfound}`, 
        await eval(indexjs.renderdataeval),
        null,
      async function (err, str) {
        delete req.session.newaccount;
        if (!req.session.userinfo || !req.session.pterodactyl) {
          if (err) {
            console.log(`[WEBSITE] An error has occured on path ${req._parsedUrl.pathname}:`);
            console.log(err);
            return res.send("An error has occured while attempting to load this page. Please contact an administrator to fix this.");
          };
          return res.send(str);
        };
  
        let cacheaccount = await fetch(
          settings.pterodactyl.domain + "/api/application/users/" + (await db.get("users-" + req.session.userinfo.id)) + "?include=servers",
          {
            method: "get",
            headers: { 'Content-Type': 'application/json', "Authorization": `Bearer ${settings.pterodactyl.key}` }
          }
        );
        if (await cacheaccount.statusText == "Not Found") {
          if (err) {
            console.log(`[WEBSITE] An error has occured on path ${req._parsedUrl.pathname}:`);
            console.log(err);
            return res.send("An error has occured while attempting to load this page. Please contact an administrator to fix this.");
          };
          return res.send(str);
        };
        let cacheaccountinfo = JSON.parse(await cacheaccount.text());
      
        req.session.pterodactyl = cacheaccountinfo.attributes;
        if (cacheaccountinfo.attributes.root_admin !== true) {
          if (err) {
            console.log(`[WEBSITE] An error has occured on path ${req._parsedUrl.pathname}:`);
            console.log(err);
            return res.send("An error has occured while attempting to load this page. Please contact an administrator to fix this.");
          };
          return res.send(str);
        };
  
        ejs.renderFile(
          `./themes/${theme.name}/${theme.settings.index}`, 
          await eval(indexjs.renderdataeval),
          null,
        function (err, str) {  
          if (err) {
            console.log(`[WEBSITE] An error has occured on path ${req._parsedUrl.pathname}:`);
            console.log(err);
            return res.send("An error has occured while attempting to load this page. Please contact an administrator to fix this.");
          };
          delete req.session.newaccount;
          res.send(str);
        });
      });
      return;
    };
    ejs.renderFile(
      `./themes/${theme.name}/${theme.settings.index}`, 
      await eval(indexjs.renderdataeval),
      null,
    function (err, str) {
      if (err) {
        console.log(`[WEBSITE] An error has occured on path ${req._parsedUrl.pathname}:`);
        console.log(err);
        return res.send("An error has occured while attempting to load this page. Please contact an administrator to fix this.");
      };
      delete req.session.newaccount;
      res.send(str);
    });
  });

  app.use('/assets', express.static('./assets'));
};