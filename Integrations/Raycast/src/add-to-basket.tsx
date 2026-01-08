import { getSelectedFinderItems, showHUD } from "@raycast/api";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

export default async function Command() {
    try {
        const items = await getSelectedFinderItems();

        if (items.length === 0) {
            await showHUD("No files selected in Finder");
            return;
        }

        // Build the droppy:// URL with encoded paths
        let url = "droppy://add?target=basket";

        for (const item of items) {
            const encodedPath = encodeURIComponent(item.path);
            url += `&path=${encodedPath}`;
        }

        // Open the URL to trigger Droppy
        await execAsync(`open "${url}"`);

        const count = items.length;
        await showHUD(`Added ${count} file${count > 1 ? "s" : ""} to Droppy Basket`);

    } catch (error) {
        await showHUD("Failed to add files to Droppy");
        console.error(error);
    }
}
