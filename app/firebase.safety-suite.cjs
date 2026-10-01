const {spawnSync}=require('node:child_process');
for(const file of ['firebase.flow.test.cjs','firestore.all-rules.test.cjs']) {
 const result=spawnSync(process.execPath,[file],{stdio:'inherit'});
 if(result.status!==0)process.exit(result.status||1);
}
