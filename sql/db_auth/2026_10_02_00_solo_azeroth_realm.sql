-- Re-applicable. Sets the name shown at the realm select screen.
-- Address stays 127.0.0.1 until you change it for another machine.
-- There is no worldserver.conf key for the realm name. It lives in acore_auth.realmlist.
UPDATE `realmlist` SET `name` = 'Solo Azeroth' WHERE `id` = 1;
