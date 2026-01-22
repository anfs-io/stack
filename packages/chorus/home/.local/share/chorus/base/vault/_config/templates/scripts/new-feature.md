<%*
const epicName = tp.file.title;
const currentFolder = tp.file.folder(true);
const featuresFolder = currentFolder.replace(/\/epics$/, '/features');

const featureName = await tp.system.prompt("Feature name:");
if (!featureName) return;

const templateFile = tp.file.find_tfile("_config/templates/feature");
let templateContent = await app.vault.read(templateFile);

// Replace placeholder with actual epic name
templateContent = templateContent.replace(/epic: "\[\[.*?\]\]"/, `epic: "[[${epicName}]]"`);
// Update created date
templateContent = templateContent.replace(/created: .*/, `created: ${tp.date.now("YYYY-MM-DD")}`);

const folder = app.vault.getAbstractFileByPath(featuresFolder);
await tp.file.create_new(templateContent, featureName, true, folder);
_%>
