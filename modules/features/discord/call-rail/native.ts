import { IpcMainInvokeEvent } from "electron";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";

const stateFile = join(process.env.XDG_RUNTIME_DIR || "/tmp", "vjshell", "discord-call.json");

export function write(_: IpcMainInvokeEvent, state: string) {
    mkdirSync(dirname(stateFile), { recursive: true });
    writeFileSync(stateFile, state);
}
