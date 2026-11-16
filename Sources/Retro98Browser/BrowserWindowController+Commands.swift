import AppKit
import Retro98UI

/// The window's commands, sent up the responder chain by both menu bars (the window's delegate is in it).
extension BrowserWindowController {
    @objc func newTab(_ sender: Any?) { openTab() }
    @objc func closeTab(_ sender: Any?) { closeTab(at: selectedIndex) }

    @objc func goBack(_ sender: Any?) { selectedTab.page.goBack() }
    @objc func goForward(_ sender: Any?) { selectedTab.page.goForward() }
    @objc func stopLoading(_ sender: Any?) { selectedTab.page.stop() }
    @objc func reloadPage(_ sender: Any?) { selectedTab.page.reload() }

    @objc func goHome(_ sender: Any?) {
        addressBar.endEditing()
        selectedTab.page.load(homeTarget)
    }

    @objc func focusAddress(_ sender: Any?) { addressBar.focus(in: window) }

    @objc func openFile(_ sender: Any?) {
        guard let file = services.dialogs.chooseFileToOpen(in: services.home, languages: languages) else { return }
        load(file)
    }

    @objc func selectNextTab(_ sender: Any?) { selectTab(at: (selectedIndex + 1) % tabs.count) }
    @objc func selectPreviousTab(_ sender: Any?) { selectTab(at: (selectedIndex + tabs.count - 1) % tabs.count) }

    /// The menu item's tag is the tab's number, 1 to 9.
    @objc func selectTabByNumber(_ sender: Any?) {
        if let item = sender as? NSMenuItem { selectTab(number: item.tag) }
    }

    @objc func zoomIn(_ sender: Any?) { setZoom(selectedTab.page.zoom * Self.zoomStep) }
    @objc func zoomOut(_ sender: Any?) { setZoom(selectedTab.page.zoom / Self.zoomStep) }
    @objc func zoomReset(_ sender: Any?) { setZoom(1) }

    private func setZoom(_ zoom: Double) {
        selectedTab.page.zoom = min(max(zoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    /// Adds the page (not the built-in ones) to the favorites and says so in the status bar.
    @objc func addFavorite(_ sender: Any?) {
        let page = selectedTab.page
        guard let url = page.url, let scheme = url.scheme?.lowercased(), HistoryStore.recordedSchemes.contains(scheme) else { return }
        let title = BrowserText.tabTitle(pageTitle: page.title, url: url, languages)
        let isNew = services.favorites.add(title: title, url: url)
        notice = isNew ? BrowserText.favoriteAdded(languages) : BrowserText.favoriteAlreadyThere(languages)
    }

    @objc func useCurrentPageAsHome(_ sender: Any?) {
        guard let url = selectedTab.page.url, let scheme = url.scheme?.lowercased(), HistoryStore.recordedSchemes.contains(scheme) else { return }
        services.preferences.homePage = url.absoluteString
        notice = BrowserText.homePageChanged(languages)
    }

    @objc func useDefaultHome(_ sender: Any?) {
        services.preferences.homePage = AddressInput.homeText
        notice = BrowserText.homePageChanged(languages)
    }
}
