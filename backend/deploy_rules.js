const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const sa = require('./serviceAccountKey.json');

const app = admin.initializeApp({
  credential: admin.credential.cert(sa),
  projectId: 'continuum-health-b54cb'
});

async function deploy() {
  const tokenObj = await app.options.credential.getAccessToken();
  const token = tokenObj.access_token;
  const rulesPath = path.resolve(__dirname, '../firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');

  console.log('Deploying ruleset to continuum-health-b54cb...');
  const createRes = await fetch('https://firebaserules.googleapis.com/v1/projects/continuum-health-b54cb/rulesets', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      source: {
        files: [{
          name: 'firestore.rules',
          content: rulesContent
        }]
      }
    })
  });

  const createData = await createRes.json();
  if (!createRes.ok) {
    console.error('Failed to create ruleset:', createData);
    process.exit(1);
  }
  console.log('Ruleset created:', createData.name);

  const releaseRes = await fetch('https://firebaserules.googleapis.com/v1/projects/continuum-health-b54cb/releases/cloud.firestore', {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      release: {
        name: 'projects/continuum-health-b54cb/releases/cloud.firestore',
        rulesetName: createData.name
      }
    })
  });

  const releaseData = await releaseRes.json();
  if (!releaseRes.ok) {
    console.error('Failed to release ruleset:', releaseData);
    process.exit(1);
  }
  console.log('Ruleset released successfully to cloud.firestore:', releaseData.rulesetName);
}

deploy().then(() => process.exit(0)).catch(e => {
  console.error(e);
  process.exit(1);
});
