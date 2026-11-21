.pragma library
// Scroll the Flickable an item is in so the item shows, with a little room: for controls the
// keyboard reaches in a scrolling page (Settings).

function show(item, room) {
    room = room ?? 12;
    for (let f = item.parent; f; f = f.parent) {
        if (f.contentY === undefined || !f.contentItem) continue;
        const y = item.mapToItem(f.contentItem, 0, 0).y;
        if (y < f.contentY) f.contentY = Math.max(0, y - room);
        else if (y + item.height > f.contentY + f.height) f.contentY = Math.min(f.contentHeight - f.height, y + item.height - f.height + room);
        return;
    }
}
