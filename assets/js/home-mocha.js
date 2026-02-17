(() => {
  const portfolioItems = [
    {
      id: "1",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_SwimwearShoot-ElleTimeless-001.jpg",
      title: "DaveBlake_SwimwearShoot-ElleTimeless-001.jpg",
    },
    {
      id: "2",
      type: "video",
      src: "/assets/images/pages/home/image-asset.jpeg",
      vimeoId: "812615935",
      aspect: 426 / 240,
      title: "COACH x Remix - Pink Train",
    },
    {
      id: "3",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_COACH-Remix-TrainEditorial-001_47.jpg",
      title: "DaveBlake_COACH-Remix-TrainEditorial-001_47.jpg",
    },
    {
      id: "4",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_CoachFW24-Street_20.jpg",
      title: "DaveBlake_CoachFW24-Street_20.jpg",
    },
    {
      id: "5",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake-JasmineDwyer_91--dc6c8f6a.jpg",
      title: "DaveBlake-JasmineDwyer_91.jpg",
    },
    {
      id: "6",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_isabelle-marcovich-beach-shoot-byron-bay_660.jpg",
      title: "DaveBlake_isabelle-marcovich-beach-shoot-byron-bay_660.jpg",
    },
    {
      id: "7",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake-MelanieAydee-gosee_039_1.jpg",
      title: "DaveBlake-MelanieAydee-gosee_039_1.jpg",
    },
    {
      id: "8",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake-MelanieAydee-gosee_215_1.jpg",
      title: "DaveBlake-MelanieAydee-gosee_215_1.jpg",
    },
    {
      id: "9",
      type: "video",
      src: "/assets/images/pages/home/image-asset--5f08c196.jpeg",
      vimeoId: "727599460",
      aspect: 240 / 426,
      title: "Video 727599460",
    },
    {
      id: "10",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_NYFW-OliviaVinten-001.jpg",
      title: "DaveBlake_NYFW-OliviaVinten-001.jpg",
    },
    {
      id: "11",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_StudioBW-AnishaProfile-001.jpg",
      title: "DaveBlake_StudioBW-AnishaProfile-001.jpg",
    },
    {
      id: "12",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_BeautyStory-RosesAndRevelations-001_159.jpg",
      title: "DaveBlake_BeautyStory-RosesAndRevelations-001_159.jpg",
    },
    {
      id: "13",
      type: "video",
      src: "/assets/images/pages/home/image-asset--4017c44d.jpeg",
      vimeoId: "772980437",
      aspect: 426 / 240,
      title: "Video 772980437",
    },
    {
      id: "14",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_EktachromeShoot-BronteSun-001-1.jpg",
      title: "DaveBlake_EktachromeShoot-BronteSun-001-1.jpg",
    },
    {
      id: "15",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_BeautyShoot-LongLensTribute-001.jpg",
      title: "DaveBlake_BeautyShoot-LongLensTribute-001.jpg",
    },
    {
      id: "16",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_BB-TestShoot-80sShorts-001.jpg",
      title: "DaveBlake_BB-TestShoot-80sShorts-001.jpg",
    },
    {
      id: "17",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_GrittyPrettyShoot-BackDetail-001.jpg",
      title: "DaveBlake_GrittyPrettyShoot-BackDetail-001.jpg",
    },
    {
      id: "18",
      type: "video",
      src: "/assets/images/pages/home/image-asset--bd872e98.jpeg",
      vimeoId: "737791008",
      aspect: 240 / 426,
      title: "Lissy's Ballet Elegance: Double-Exposure in Monochrome",
    },
    {
      id: "19",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_GC-TestShoot-MichelleB-001.jpg",
      title: "DaveBlake_GC-TestShoot-MichelleB-001.jpg",
    },
    {
      id: "20",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_StudioShoot-BelleVive-001.jpg",
      title: "DaveBlake_StudioShoot-BelleVive-001.jpg",
    },
    {
      id: "21",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_DenimShoot-JaseMotorcycle-001.jpg",
      title: "DaveBlake_DenimShoot-JaseMotorcycle-001.jpg",
    },
    {
      id: "22",
      type: "image",
      src: "/assets/images/pages/home/LH_0804-1.jpg",
      title: "LH_0804-1.jpg",
    },
    {
      id: "23",
      type: "image",
      src: "/assets/images/pages/home/LH_0403-1.jpg",
      title: "LH_0403-1.jpg",
    },
    {
      id: "24",
      type: "image",
      src: "/assets/images/pages/home/LH_0300.jpg",
      title: "LH_0300.jpg",
    },
    {
      id: "25",
      type: "image",
      src: "/assets/images/pages/home/DaveBlake_FieldShoot-KateHorse-001.jpg",
      title: "DaveBlake_FieldShoot-KateHorse-001.jpg",
    },
    {
      id: "26",
      type: "video",
      src: "/assets/images/pages/home/image-asset--a23a3106.jpeg",
      vimeoId: "269971275",
      aspect: 640 / 360,
      title: "Video 269971275",
    },
    {
      id: "27",
      type: "image",
      src: "/assets/images/pages/home/image-asset--d3f36cbf.jpeg",
      title: "image-asset--d3f36cbf.jpeg",
    },
    {
      id: "28",
      type: "image",
      src: "/assets/images/pages/home/by_Dave_Blake_20220129_Flower4778__2022_1.jpg",
      title: "by_Dave_Blake_20220129_Flower4778__2022_1.jpg",
    },
    {
      id: "29",
      type: "image",
      src: "/assets/images/pages/home/27.jpg",
      title: "social_worldwide_Nov2022_AnnaFeller-Coach-MicroMini",
    },
  ];

  const mediaAspectById = {
    "1": 666 / 998,
    "2": 426 / 240,
    "3": 800 / 1200,
    "4": 857 / 1200,
    "5": 1200 / 800,
    "6": 1200 / 800,
    "7": 2500 / 3499,
    "8": 2500 / 3499,
    "9": 240 / 426,
    "10": 857 / 1200,
    "11": 1200 / 1200,
    "12": 800 / 1200,
    "13": 426 / 240,
    "14": 750 / 1124,
    "15": 816 / 1200,
    "16": 960 / 1200,
    "17": 800 / 1200,
    "18": 240 / 426,
    "19": 960 / 1200,
    "20": 801 / 1200,
    "21": 801 / 1200,
    "22": 1534 / 1024,
    "23": 1024 / 1534,
    "24": 1534 / 1024,
    "25": 801 / 1200,
    "26": 640 / 360,
    "27": 1367 / 2048,
    "28": 1024 / 1434,
    "29": 864 / 1080,
  };

  const mobileToggle = document.getElementById("mobile-menu-toggle");
  const mobileMenu = document.getElementById("mobile-menu");
  const mobileLinks = Array.from(
    document.querySelectorAll("[data-close-mobile-menu]")
  );
  const disclosureButtons = Array.from(
    document.querySelectorAll("[data-disclosure-target]")
  );
  const masonryGrid = document.getElementById("masonry-grid");

  const viewer = document.getElementById("image-viewer");
  const viewerFrame = document.getElementById("viewer-frame");
  const viewerImage = document.getElementById("viewer-image");
  const viewerVideo = document.getElementById("viewer-video");
  const viewerCounter = document.getElementById("viewer-counter");
  const viewerPrev = document.getElementById("viewer-prev");
  const viewerNext = document.getElementById("viewer-next");
  const viewerClose = document.getElementById("viewer-close");
  const footerYear = document.getElementById("footer-year");

  if (
    !(mobileToggle instanceof HTMLButtonElement) ||
    !(mobileMenu instanceof HTMLElement) ||
    !(masonryGrid instanceof HTMLElement) ||
    !(viewer instanceof HTMLElement) ||
    !(viewerFrame instanceof HTMLElement) ||
    !(viewerImage instanceof HTMLImageElement) ||
    !(viewerVideo instanceof HTMLIFrameElement) ||
    !(viewerCounter instanceof HTMLElement) ||
    !(viewerPrev instanceof HTMLButtonElement) ||
    !(viewerNext instanceof HTMLButtonElement) ||
    !(viewerClose instanceof HTMLButtonElement)
  ) {
    return;
  }

  let mobileMenuOpen = false;
  let viewerOpen = false;
  let currentIndex = 0;
  let touchStartX = null;
  let touchEndX = null;
  let gridItems = [];
  let gridObserver = null;
  let currentGridColumnCount = 0;
  let resizeTimer = null;

  const loadedIds = new Set();
  const visibleIds = new Set();
  const videoTileByPlayerId = new Map();

  const getVimeoPreviewSrc = (vimeoId, playerId) =>
    "https://player.vimeo.com/video/" +
    vimeoId +
    "?api=1&background=1&autoplay=1&muted=1&loop=1&quality=480p&autopause=0&player_id=" +
    encodeURIComponent(playerId);

  const getVimeoViewerSrc = (vimeoId) =>
    "https://player.vimeo.com/video/" +
    vimeoId +
    "?autoplay=1&muted=1&title=0&byline=0&portrait=0";

  const getGridColumnCount = () => {
    const width = window.innerWidth;
    if (width >= 1024) {
      return 3;
    }
    if (width >= 640) {
      return 2;
    }
    return 1;
  };

  const getMediaAspect = (item) => {
    if (typeof item.aspect === "number" && Number.isFinite(item.aspect) && item.aspect > 0) {
      return item.aspect;
    }
    const mappedAspect = mediaAspectById[item.id];
    if (
      typeof mappedAspect === "number" &&
      Number.isFinite(mappedAspect) &&
      mappedAspect > 0
    ) {
      return mappedAspect;
    }
    return 16 / 9;
  };

  const applyViewerVideoLayout = (item) => {
    const aspect = getMediaAspect(item);
    const maxWidth = Math.min(window.innerWidth * 0.92, 1800);
    const maxHeight = Math.max(240, window.innerHeight - 112);
    let width = maxWidth;
    let height = width / aspect;

    if (height > maxHeight) {
      height = maxHeight;
      width = height * aspect;
    }

    viewerFrame.style.width = Math.max(160, Math.round(width)) + "px";
    viewerFrame.style.height = Math.max(120, Math.round(height)) + "px";
  };

  const resetViewerVideoLayout = () => {
    viewerFrame.style.removeProperty("width");
    viewerFrame.style.removeProperty("height");
  };

  const parseVimeoMessage = (data) => {
    if (!data) {
      return null;
    }

    if (typeof data === "string") {
      if (!data.startsWith("{")) {
        return null;
      }

      try {
        return JSON.parse(data);
      } catch (_error) {
        return null;
      }
    }

    if (typeof data === "object") {
      return data;
    }

    return null;
  };

  const subscribeToVimeoEvents = (iframe) => {
    const target = iframe.contentWindow;
    if (!target) {
      return;
    }

    ["ready", "play", "pause", "ended"].forEach((eventName) => {
      target.postMessage(
        JSON.stringify({
          method: "addEventListener",
          value: eventName,
        }),
        "https://player.vimeo.com"
      );
    });
  };

  const handleVimeoMessage = (event) => {
    if (typeof event.origin !== "string" || !event.origin.includes("player.vimeo.com")) {
      return;
    }

    const payload = parseVimeoMessage(event.data);
    if (!payload || typeof payload !== "object") {
      return;
    }

    const playerId = payload.player_id;
    if (!playerId || typeof playerId !== "string") {
      return;
    }

    const tile = videoTileByPlayerId.get(playerId);
    if (!tile) {
      return;
    }

    if (payload.event === "ready") {
      const iframe = document.getElementById(playerId);
      if (iframe instanceof HTMLIFrameElement) {
        subscribeToVimeoEvents(iframe);
      }
      return;
    }

    if (payload.event === "play") {
      tile.classList.add("is-playing");
      return;
    }

    if (payload.event === "pause" || payload.event === "ended") {
      tile.classList.remove("is-playing");
    }
  };

  const updateBodyLock = () => {
    document.body.classList.toggle("lock-scroll", mobileMenuOpen || viewerOpen);
  };

  const setMobileMenuOpen = (isOpen) => {
    mobileMenuOpen = isOpen;
    mobileMenu.classList.toggle("is-open", isOpen);
    mobileMenu.setAttribute("aria-hidden", String(!isOpen));
    mobileToggle.setAttribute("aria-expanded", String(isOpen));
    updateBodyLock();
  };

  const setFooterYear = () => {
    if (footerYear) {
      footerYear.textContent = String(new Date().getFullYear());
    }
  };

  const renderGrid = () => {
    const columnCount = getGridColumnCount();
    currentGridColumnCount = columnCount;
    masonryGrid.style.setProperty("--masonry-columns", String(columnCount));

    const fragment = document.createDocumentFragment();
    const columnElements = [];
    const columnHeights = new Array(columnCount).fill(0);
    videoTileByPlayerId.clear();

    for (let i = 0; i < columnCount; i += 1) {
      const column = document.createElement("div");
      column.className = "masonry-column";
      columnElements.push(column);
      fragment.appendChild(column);
    }

    portfolioItems.forEach((item, index) => {
      const aspect = getMediaAspect(item);
      const figure = document.createElement("figure");
      figure.className = "grid-item" + (item.type === "video" ? " has-video" : "");
      figure.setAttribute("data-id", item.id);
      figure.setAttribute("data-index", String(index));
      if (item.type === "video") {
        figure.style.setProperty("--media-aspect", String(aspect));
      }

      const button = document.createElement("button");
      button.type = "button";
      button.className = "grid-item-button";
      button.setAttribute("data-open-viewer", String(index));
      button.setAttribute("aria-label", "Open media " + String(index + 1));

      const placeholder = document.createElement("span");
      placeholder.className = "grid-placeholder";
      placeholder.setAttribute("aria-hidden", "true");
      button.appendChild(placeholder);

      if (item.type === "video" && item.vimeoId) {
        const playerId = "grid-video-" + item.id;
        figure.setAttribute("data-player-id", playerId);
        videoTileByPlayerId.set(playerId, figure);

        const videoPreview = document.createElement("iframe");
        videoPreview.className = "grid-video-preview";
        videoPreview.id = playerId;
        videoPreview.src = getVimeoPreviewSrc(item.vimeoId, playerId);
        videoPreview.title = item.title + " preview";
        videoPreview.loading = "lazy";
        videoPreview.allow = "autoplay; fullscreen; picture-in-picture";
        videoPreview.setAttribute("aria-hidden", "true");
        videoPreview.tabIndex = -1;
        videoPreview.addEventListener("load", () => {
          subscribeToVimeoEvents(videoPreview);
        });
        button.appendChild(videoPreview);

        const videoIcon = document.createElement("span");
        videoIcon.className = "grid-video-icon";
        videoIcon.setAttribute("aria-hidden", "true");
        videoIcon.innerHTML =
          '<svg viewBox="0 0 24 24"><path d="M8 6l10 6-10 6z"></path></svg>';
        button.appendChild(videoIcon);
      }

      const image = document.createElement("img");
      image.className = "grid-image";
      image.src = item.src;
      image.alt = item.title;
      image.loading = "lazy";
      button.appendChild(image);

      const hoverOverlay = document.createElement("span");
      hoverOverlay.className = "grid-hover-overlay";
      hoverOverlay.setAttribute("aria-hidden", "true");
      button.appendChild(hoverOverlay);

      figure.appendChild(button);
      let targetColumnIndex = 0;
      for (let i = 1; i < columnCount; i += 1) {
        if (columnHeights[i] < columnHeights[targetColumnIndex]) {
          targetColumnIndex = i;
        }
      }
      const targetColumn = columnElements[targetColumnIndex];
      targetColumn.appendChild(figure);
      columnHeights[targetColumnIndex] += 1 / Math.max(0.08, aspect);
    });

    masonryGrid.innerHTML = "";
    masonryGrid.appendChild(fragment);
    gridItems = Array.from(masonryGrid.querySelectorAll(".grid-item"));
  };

  const syncGridItemState = (item, id) => {
    const isLoaded = loadedIds.has(id);
    const isVisible = visibleIds.has(id);
    item.classList.toggle("is-loaded", isLoaded);
    item.classList.toggle("is-visible", isVisible);
    item.classList.toggle("is-ready", isLoaded && isVisible);
  };

  const initializeGridAnimation = () => {
    if (gridObserver) {
      gridObserver.disconnect();
      gridObserver = null;
    }

    gridItems.forEach((item) => {
      const id = item.getAttribute("data-id");
      const image = item.querySelector(".grid-image");

      if (!id || !(image instanceof HTMLImageElement)) {
        return;
      }

      const handleLoad = () => {
        loadedIds.add(id);
        syncGridItemState(item, id);
      };

      if (image.complete && image.naturalWidth > 0) {
        handleLoad();
      } else {
        image.addEventListener("load", handleLoad, { once: true });
      }
    });

    if ("IntersectionObserver" in window) {
      const observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting) {
              return;
            }

            const observed = entry.target;
            if (!(observed instanceof HTMLElement)) {
              return;
            }

            const id = observed.getAttribute("data-id");
            if (!id) {
              return;
            }

            visibleIds.add(id);
            syncGridItemState(observed, id);
          });
        },
        {
          threshold: 0.1,
          rootMargin: "50px",
        }
      );

      gridItems.forEach((item) => observer.observe(item));
      gridObserver = observer;
      return;
    }

    gridItems.forEach((item) => {
      const id = item.getAttribute("data-id");
      if (!id) {
        return;
      }
      visibleIds.add(id);
      syncGridItemState(item, id);
    });
  };

  const handleResize = () => {
    if (resizeTimer !== null) {
      window.clearTimeout(resizeTimer);
    }

    resizeTimer = window.setTimeout(() => {
      const nextColumnCount = getGridColumnCount();
      if (nextColumnCount !== currentGridColumnCount) {
        renderGrid();
        initializeGridAnimation();
      }

      if (viewerOpen) {
        const activeItem = portfolioItems[currentIndex];
        if (activeItem && activeItem.type === "video") {
          applyViewerVideoLayout(activeItem);
        }
      }
    }, 140);
  };

  const updateViewerButtons = () => {
    viewerPrev.disabled = currentIndex <= 0;
    viewerNext.disabled = currentIndex >= portfolioItems.length - 1;
  };

  const updateViewerCounter = () => {
    const current = String(currentIndex + 1).padStart(2, "0");
    const total = String(portfolioItems.length).padStart(2, "0");
    viewerCounter.textContent = current + " / " + total;
  };

  const loadViewerMedia = () => {
    const item = portfolioItems[currentIndex];
    if (!item) {
      return;
    }

    resetViewerVideoLayout();
    viewerFrame.classList.remove("is-loaded");
    viewerFrame.classList.remove("is-video");
    viewerImage.classList.remove("is-active");
    viewerVideo.classList.remove("is-active");
    viewerVideo.src = "";
    viewerVideo.title = "";

    if (item.type === "video" && item.vimeoId) {
      viewerFrame.classList.add("is-video");
      viewerFrame.classList.add("is-loaded");
      applyViewerVideoLayout(item);
      viewerImage.removeAttribute("src");
      viewerImage.alt = "";
      viewerVideo.src = getVimeoViewerSrc(item.vimeoId);
      viewerVideo.title = item.title;
      viewerVideo.classList.add("is-active");
    } else {
      viewerImage.src = item.src;
      viewerImage.alt = item.title;
      viewerImage.classList.add("is-active");

      if (viewerImage.complete && viewerImage.naturalWidth > 0) {
        viewerFrame.classList.add("is-loaded");
      }
    }

    updateViewerButtons();
    updateViewerCounter();
  };

  const openViewer = (index) => {
    if (index < 0 || index >= portfolioItems.length) {
      return;
    }

    if (mobileMenuOpen) {
      setMobileMenuOpen(false);
    }

    currentIndex = index;
    loadViewerMedia();
    viewerOpen = true;
    viewer.classList.add("is-open");
    viewer.setAttribute("aria-hidden", "false");
    updateBodyLock();
  };

  const closeViewer = () => {
    viewerOpen = false;
    viewer.classList.remove("is-open");
    viewer.setAttribute("aria-hidden", "true");
    viewerVideo.src = "";
    resetViewerVideoLayout();
    updateBodyLock();
  };

  const navigateViewer = (offset) => {
    const nextIndex = currentIndex + offset;
    if (nextIndex < 0 || nextIndex >= portfolioItems.length) {
      return;
    }
    currentIndex = nextIndex;
    loadViewerMedia();
  };

  const handleGlobalKeydown = (event) => {
    if (event.key === "Escape") {
      if (viewerOpen) {
        closeViewer();
        return;
      }

      if (mobileMenuOpen) {
        setMobileMenuOpen(false);
      }
      return;
    }

    if (!viewerOpen) {
      return;
    }

    if (event.key === "ArrowLeft") {
      navigateViewer(-1);
    } else if (event.key === "ArrowRight") {
      navigateViewer(1);
    }
  };

  mobileToggle.addEventListener("click", () => {
    setMobileMenuOpen(!mobileMenuOpen);
  });

  mobileLinks.forEach((link) => {
    link.addEventListener("click", () => {
      setMobileMenuOpen(false);
    });
  });

  disclosureButtons.forEach((button) => {
    button.addEventListener("click", () => {
      const targetId = button.getAttribute("data-disclosure-target");
      if (!targetId) {
        return;
      }

      const target = document.getElementById(targetId);
      if (!(target instanceof HTMLElement)) {
        return;
      }

      const indicator = button.querySelector("[data-indicator]");
      const expanded = button.getAttribute("aria-expanded") === "true";
      const nextExpanded = !expanded;

      button.setAttribute("aria-expanded", String(nextExpanded));
      target.classList.toggle("is-open", nextExpanded);

      if (indicator instanceof HTMLElement) {
        indicator.textContent = nextExpanded ? "-" : "+";
      }
    });
  });

  viewerImage.addEventListener("load", () => {
    if (viewerImage.classList.contains("is-active")) {
      viewerFrame.classList.add("is-loaded");
    }
  });

  viewerClose.addEventListener("click", closeViewer);
  viewerPrev.addEventListener("click", () => navigateViewer(-1));
  viewerNext.addEventListener("click", () => navigateViewer(1));

  viewer.addEventListener("click", (event) => {
    if (event.target === viewer) {
      closeViewer();
    }
  });

  viewer.addEventListener("touchstart", (event) => {
    if (!viewerOpen) {
      return;
    }
    touchStartX = event.touches[0].clientX;
    touchEndX = event.touches[0].clientX;
  });

  viewer.addEventListener("touchmove", (event) => {
    if (!viewerOpen) {
      return;
    }
    touchEndX = event.touches[0].clientX;
  });

  viewer.addEventListener("touchend", () => {
    if (!viewerOpen || touchStartX === null || touchEndX === null) {
      touchStartX = null;
      touchEndX = null;
      return;
    }

    const swipeDistance = touchStartX - touchEndX;
    const threshold = 50;

    if (swipeDistance > threshold) {
      navigateViewer(1);
    } else if (swipeDistance < -threshold) {
      navigateViewer(-1);
    }

    touchStartX = null;
    touchEndX = null;
  });

  masonryGrid.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof Element)) {
      return;
    }

    const trigger = target.closest("[data-open-viewer]");
    if (!(trigger instanceof HTMLElement)) {
      return;
    }

    const rawIndex = trigger.getAttribute("data-open-viewer");
    if (!rawIndex) {
      return;
    }

    const index = Number(rawIndex);
    if (Number.isInteger(index)) {
      openViewer(index);
    }
  });

  window.addEventListener("keydown", handleGlobalKeydown);
  window.addEventListener("resize", handleResize);
  window.addEventListener("message", handleVimeoMessage);
  setFooterYear();
  renderGrid();
  initializeGridAnimation();
})();
