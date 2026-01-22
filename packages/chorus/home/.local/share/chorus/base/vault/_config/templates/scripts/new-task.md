<%*
const storyName = tp.file.title;
const currentFolder = tp.file.folder(true);
const tasksFolder = currentFolder.replace(/\/stories$/, '/tasks');

const taskName = await tp.system.prompt("Task name:");
if (!taskName) return;

const templateFile = tp.file.find_tfile("_config/templates/task");
let templateContent = await app.vault.read(templateFile);

// Replace placeholder with actual story name
templateContent = templateContent.replace(/story: "\[\[.*?\]\]"/, `story: "[[${storyName}]]"`);
// Update created date
templateContent = templateContent.replace(/created: .*/, `created: ${tp.date.now("YYYY-MM-DD")}`);

// Ensure tasks folder exists
let folder = app.vault.getAbstractFileByPath(tasksFolder);
if (!folder) {
    await app.vault.createFolder(tasksFolder);
    folder = app.vault.getAbstractFileByPath(tasksFolder);
}

await tp.file.create_new(templateContent, taskName, true, folder);
_%>
