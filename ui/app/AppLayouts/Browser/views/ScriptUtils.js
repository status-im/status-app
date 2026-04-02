.pragma library

// Check if a console message source is from one of our injected scripts
function isOurInjectedScript(sourceID, profile) {
    if (!sourceID || !profile) {
        return false;
    }

    if (!profile.userScripts || !profile.userScripts.collection) {
        return false;
    }

    const scripts = profile.userScripts.collection;
    for (let i = 0; i < scripts.length; i++) {
        if (scripts[i] && scripts[i].name && sourceID.includes(scripts[i].name)) {
            return true;
        }
    }

    return false;
}
