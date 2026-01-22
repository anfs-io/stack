<%*
const featureName = tp.file.title;
const currentFolder = tp.file.folder(true);
const storiesFolder = currentFolder.replace(/\/features$/, '/stories');

const storyName = await tp.system.prompt("Story name:");
if (!storyName) return;

const templateFile = tp.file.find_tfile("_config/templates/story");
let templateContent = await app.vault.read(templateFile);

// Replace placeholder with actual feature name
templateContent = templateContent.replace(/feature: "\[\[.*?\]\]"/, `feature: "[[${featureName}]]"`);
// Update created date
templateContent = templateContent.replace(/created: .*/, `created: ${tp.date.now("YYYY-MM-DD")}`);

const folder = app.vault.getAbstractFileByPath(storiesFolder);
await tp.file.create_new(templateContent, storyName, true, folder);
_%>
