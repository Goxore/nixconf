import definePlugin, { PluginNative } from "@utils/types";
import { User } from "@vencord/discord-types";
import { findStoreLazy } from "@webpack";
import { SelectedChannelStore, UserStore, VoiceStateStore } from "@webpack/common";

const SpeakingStore = findStoreLazy("SpeakingStore");
const Native = VencordNative.pluginHelpers.CallRail as PluginNative<typeof import("./native")>;

const AVATAR_SIZE = 64;

const stores = [SelectedChannelStore, VoiceStateStore, SpeakingStore];

const empty = {
    channelId: null,
    participants: []
};

function avatarUrl(user: User) {
    return user.getAvatarURL(undefined, AVATAR_SIZE, false).replace(/\.(webp|jpe?g)(\?|$)/, ".png$2");
}

function snapshot() {
    const channelId = SelectedChannelStore.getVoiceChannelId();
    if (channelId == null) return empty;

    const speakers = new Set<string>(SpeakingStore.getSpeakers());

    const participants = Object.values(VoiceStateStore.getVoiceStatesForChannel(channelId)).flatMap(state => {
        const user = UserStore.getUser(state.userId);
        if (user == null) return [];

        return [{
            id: user.id,
            name: user.globalName ?? user.username,
            avatar: avatarUrl(user),
            muted: state.mute || state.selfMute,
            deafened: state.deaf || state.selfDeaf,
            streaming: state.selfStream === true,
            speaking: speakers.has(user.id)
        }];
    });

    return { channelId, participants };
}

let published = "";

function publish(state = snapshot()) {
    const next = JSON.stringify(state);
    if (next === published) return;

    published = next;
    Native.write(next);
}

export default definePlugin({
    name: "CallRail",
    description: "Publishes your current voice call state for the bar to read.",
    authors: [{ name: "Yurii", id: 0n }],
    enabledByDefault: true,

    start() {
        for (const store of stores) store.addChangeListener(publish);
        publish();
    },

    stop() {
        for (const store of stores) store.removeChangeListener(publish);
        publish(empty);
    }
});
