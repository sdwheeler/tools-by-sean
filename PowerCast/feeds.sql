drop table podcasts;
CREATE TABLE podcasts (
	podcastId     INTEGER PRIMARY KEY AUTOINCREMENT,
	title          TEXT NOT NULL,
	feedUrl        TEXT NOT NULL,
	siteUrl        TEXT,
	logoUrl        TEXT,
	pubDate        TEXT,
	lastBuildDate  TEXT,
	lastSyncDate   TEXT,
	lastItemDate   TEXT,
	folder         TEXT,
	logoFile       TEXT,
	genre          TEXT,
	subscribed     BOOLEAN,
	autodownload   BOOLEAN
);

drop table episodes;
CREATE TABLE episodes (
    episodeId    INTEGER PRIMARY KEY AUTOINCREMENT,
    title        TEXT NOT NULL,
    link         TEXT,
    pubDate      TEXT,
    lastSyncDate TEXT,
    guid         TEXT NOT NULL,
    enclosure    TEXT,	
    filesize     UNSIGNED BIG INT,	
    duration     TEXT,
    filename     TEXT,
    download     BOOLEAN,
    feedId	     INT
);

drop table downloads;
CREATE TABLE downloads (
    rowId        INTEGER PRIMARY KEY,
    JobId        TEXT,
    podcastId    INTEGER,
    episodeId    INTEGER,
    Filename     TEXT,
    AssetType    TEXT
);