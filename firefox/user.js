// Follow the desktop's light/dark setting everywhere, including the home page. Firefox reads it
// from the xdg-desktop-portal, which reports GNOME's style (dark, set by the-script-gnome).
user_pref("browser.theme.toolbar-theme", 2);
user_pref("browser.theme.content-theme", 2);
user_pref("layout.css.prefers-color-scheme.content-override", 2);
// Tabs in the title bar, like other GNOME apps (the Windows 7 desktop had them under its own title bar).
user_pref("browser.tabs.inTitlebar", 1);
// Scaling comes from GNOME's per-monitor scale (Settings > Displays). Do not also set
// layout.css.devPixelsPerPx here -- Firefox multiplies the two (2.25x).
user_pref("layout.css.devPixelsPerPx", "-1.0");

// ---- Settings carried over from the author's Firefox ----
// Note: Firefox re-applies everything in this file on each start, so changing one of these in
// about:preferences only lasts until Firefox is restarted. Edit or delete the line here instead.

// No AI features (chatbot, link previews, smart tab groups, translations, local ML)
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.translations", "blocked");
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.tabs.groups.smart.userEnabled", false);
user_pref("browser.translations.enable", false);
user_pref("extensions.ml.enabled", false);
user_pref("browser.smartwindow.memories.generateFromConversation", false);
user_pref("browser.smartwindow.memories.generateFromHistory", false);

// Quiet new-tab page: no sponsored tiles, top stories, top sites or weather
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.widgets.weather.enabled", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons", false);
user_pref("browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features", false);

// Address bar: no suggestions beyond what you type
user_pref("browser.urlbar.suggest.bookmark", false);
user_pref("browser.urlbar.suggest.engines", false);
user_pref("browser.urlbar.suggest.openpage", false);
user_pref("browser.urlbar.suggest.quickactions", false);
user_pref("browser.urlbar.suggest.quicksuggest.all", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.recentsearches", false);
user_pref("browser.urlbar.suggest.topsites", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.search.suggest.enabled.private", true);

// Interface
user_pref("browser.toolbars.bookmarks.visibility", "never");
user_pref("sidebar.visibility", "hide-on-close");
user_pref("browser.download.useDownloadDir", false);   // ask where to save each download

// Passwords live in KeePassXC, not Firefox; no autofill of addresses or cards
user_pref("signon.rememberSignons", false);
user_pref("signon.firefoxRelay.feature", "disabled");
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);

// Privacy and tracking protection
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.emailtracking.enabled", true);
user_pref("privacy.trackingprotection.allow_list.convenience.enabled", false);
user_pref("privacy.trackingprotection.consentmanager.skip.pbmode.enabled", false);
user_pref("privacy.annotate_channels.strict_list.enabled", true);
user_pref("privacy.bounceTrackingProtection.mode", 1);
user_pref("privacy.fingerprintingProtection", true);
user_pref("privacy.query_stripping.enabled", true);
user_pref("privacy.query_stripping.enabled.pbmode", true);
user_pref("privacy.userContext.enabled", false);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation", true);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("permissions.default.desktop-notification", 2);   // block notification requests
user_pref("permissions.default.geo", 2);                    // block location requests
