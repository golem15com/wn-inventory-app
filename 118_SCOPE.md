Numbering might be weird, but i'm ophi118 and this is my stack v1.1.0 + a set of fixes and a set of additional features explained below and this version will serve as an LTS version which must always work, as long as php8.5 is supported.

Phase 1:  Prerequisites

- Give a full report on submodules states. Check for feature branches, develop vs master status, tags. We expect them all be merged with their latest state to master and tagged correctly at the end of this milestone, but this is review phase and much of phase 2 planning depends on it. 
- We will need a script to reset GSD for fresh projects. New script, but flag on setup.sh should run it. Script will:
  - Confirm it's remote origin is fresh and empty and not a default repo with a wn-starter-app in its name
  - When confirmed, reset all tags on this repo
  - Archive the starter pack planning documentation - we need to decide what to leave for fresh GSD and what to archive.
  - Goal is that /gsd-new-project works but GSD is instantly aware that this was a GSD project that resulted in starter stack, allows v1.0 or whatever milestone user wants and just nicely guides trough a new client project based on starter.
  
Phase 2:  

- Upgrading submodules. Mainly UAT phase where we go plugin by plugin and confirm latest master that will be pinned to this LTS is OK.
- Core planning to do, after phase 1 results. 

Phase 3: 
- vue-starter-app !
- Requires analysis of: horoskopia.eu, golem15.com, drzewo.net, queststream.online, wavepath.org, potentially golemxv.com. For common component set best fitting a starter vue theme for headless WinterCMS. We scaffold it from scratch too often. 
- Simple, yet perfect for scaffolding new apps considering stuff already done. 
