# Docker Compose Rebuild & Restart Guide

This guide explains **when** to restart, recreate, or rebuild Docker Compose services depending on what changed.

---

## 🔄 When to Just Restart
Use when only runtime state changed:
- ROS params, `.rviz` configs, launch args.
- Services stuck but no config or image changes.

```bash
docker compose restart
```

---

## ♻️ When to Recreate Containers (No Image Rebuild)
Use when you changed **Compose config**:
- Edited `docker-compose.yml` (ports, env vars, volumes, networks).
- Updated `.env` file.
- Want a clean runtime state but keep same image.

```bash
docker compose up -d           # recreate as needed
docker compose up -d --force-recreate  # force recreation
```

---

## 🏗️ When to Rebuild Images (and Recreate Containers)
Use when you changed the **Dockerfile** or anything it COPY/ADDs:
- Installed new apt packages or ROS dependencies.
- Changed base image.
- Need to refresh bad cache layers.

```bash
docker compose build           # rebuild with cache
docker compose build --no-cache  # full rebuild
docker compose up -d --build     # rebuild + recreate
```

---

## 🗑️ When to Delete Containers First
Use when containers are in a weird state or config changed drastically:
- Old service names linger.
- Volumes/paths changed.

```bash
docker compose down
docker compose up -d --build
```

---

## 📦 When to Nuke Volumes (Data Reset)
Use when you want a **fresh workspace**:
- Remove cached workspace builds.
- Reset corrupted persistent data.

```bash
docker compose down -v
docker volume prune
```

⚠️ Warning: deletes **all persistent data** in volumes.

---

## 🧹 When to Prune Images/Layers (Disk Cleanup)
Use when low on disk space or stale images remain:
- Free unused images, networks, and build caches.

```bash
docker image prune -a           # unused images
docker builder prune -a         # build cache
docker system prune -a --volumes  # ⚠️ aggressive
```

---

## ✅ Quick Decision Cheat-Sheet
- **Edited source code (bind-mounted)?** → Restart or recreate.  
- **Changed Dockerfile / installed deps?** → Rebuild image + up.  
- **Edited `docker-compose.yml`?** → `up -d` (add `--force-recreate` if needed).  
- **Weird DDS/ROS state?** → `restart` or `down && up -d`.  
- **Need clean workspace?** → `down -v && up -d --build`.  
- **Low disk space?** → Prune images & build cache.

---

## 🔧 Safe “Clean Rebuild” Sequences

### Fresh build without wiping data
```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Full reset (includes volumes/data)
```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Kill leftovers manually (if Compose refuses)
```bash
docker ps -a --format "table {{.Names}}	{{.Image}}	{{.Status}}"
docker stop $(docker ps -q)
docker rm $(docker ps -aq)
```

---

## 📌 Summary
- Use the **lightest touch** needed.
- Restart → Recreate → Rebuild → Reset → Prune (in that order).
- Saves time and avoids unnecessary rebuilds.
