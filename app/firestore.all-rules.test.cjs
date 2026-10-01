const {spawnSync} = require('node:child_process');
for (const file of ['firestore.rules.test.cjs','parent-invite.rules.test.cjs','child-invite.rules.test.cjs','join-request.rules.test.cjs','firestore.permissions.test.cjs','firestore.chat-safety.test.cjs','functions/join-request.test.cjs','functions/chat-safety.test.cjs']) {
 console.log('RUN '+file);
 const result=spawnSync(process.execPath,[file],{stdio:'inherit'});
 if(result.status!==0) process.exit(result.status||1);
}
