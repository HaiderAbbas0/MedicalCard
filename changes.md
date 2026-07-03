> ⚠️ **HISTORICAL — describes the retired in-memory Node/Express prototype.**
> The production architecture is now **Supabase-first** (see the root `README.md`).
> The `/backend` folder and `.env`/`WIFI_IP` setup described below no longer exist.
> Kept only as a record of the earlier prototype.

# Changes Log — SehatID Patient App & Local Backend Setup

This document describes all the changes made to the codebase since cloning the repository, explained in plain language.

---

## 1. Split Backend from Frontend
* **Before**: The mobile application had its database connections and server URLs hardcoded to an online production server (`https://sehatid-backend-production.up.railway.app`). When that server went offline, the app failed to function, relying only on fake "offline simulator" data.
* **Now**: We created a dedicated, standalone **`backend/`** folder. This serves as a private, local server that runs on your computer. It handles all logins, registrations, visits, prescriptions, and messaging data.

---

## 2. Added a Dedicated Local Backend Service
We created a new backend codebase in the [backend/](file:///d:/MedicalCard/backend) directory:
* **`server.js`**: A Node.js application that runs on your computer. It hosts the API for logging in, registering accounts, fetching medical records, and sending messages.
* **`package.json`**: Lists the software libraries required by the server (Express and CORS).
* **`run_backend.bat`**: A double-clickable script in the root folder. Running this automatically installs dependencies and starts your local server on port `3000`.

---

## 3. Dynamic Network & Security Configuration (IP and `.env` Setup)
* **Private `.env` File**: We created a local `.env` file that stores your computer's specific Wi-Fi IP address (`192.168.100.4`).
* **Environment Template (`tempEnv`)**: We created a template file called `tempEnv` containing placeholder text. Other developers can copy this file, rename it to `.env`, and insert their own Wi-Fi IP address.
* **Dynamic Configuration (`api_config.dart`)**: We created a central configuration file inside the Flutter app. Instead of hardcoding your IP address into the app code, it dynamically reads the IP from the `.env` file during build time. This ensures you can push your code to GitHub without sharing your home Wi-Fi details.
* **Centralized APIs**: We replaced duplicate URL configurations across the app (in auth, chat, and record services) to reference this single config file.

---

## 4. Automation & Git Safety
* **Updated Launch Scripts**: We modified the batch files `mobileClone.bat` and `run_test.bat` to automatically load the `.env` file whenever you launch the app on your phone or in Chrome.
* **Ignored Local files (`.gitignore`)**: Added local scripts (`mobileClone.bat`, `run_test.bat`) and private settings (`.env`) to `.gitignore` so they are not uploaded to GitHub.



----------------
DATABASE SCENE
----------------

Currently, all user login information and patient data are stored in-memory (in the RAM of the running Node.js process) inside your local backend server:

Location in Code: It is defined in the users array at the top of 

server.js
.
Initial/Seed User: It is pre-filled with the demo account:
Email: ayesha@example.com
Password: password123
Sign-Up/Registration: When you register a new user using the mobile app, that user's details are dynamically added to the users array in memory.
Important Note on In-Memory Storage:
Because the data is stored in the server's memory (RAM) for easy local testing:

The data will persist as long as the backend terminal window remains open and running.
If you restart the backend server (close the terminal and run the .bat file again), the database resets back to its original clean state (only the default ayesha@example.com account will remain, and newly registered accounts will be cleared).
This is the standard approach for quick development and testing because it saves you from having to install and configure a database system (like MySQL or MongoDB) on your PC.