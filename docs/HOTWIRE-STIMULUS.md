# Hotwire & Stimulus Implementation

## Overview
This document describes the Hotwire (Turbo + Stimulus) features implemented in the PR Knowledge Hub application.

## Stimulus Controllers

### 1. Search Controller (`search_controller.js`)
**Purpose**: Provides debounced live search functionality

**Features**:
- Auto-submits search form after user stops typing (300ms delay)
- Prevents excessive API calls
- Works with Turbo Frames for seamless updates

**Usage**:
```erb
<form data-controller="search" data-turbo-frame="search_results">
  <input data-search-target="input" data-action="input->search#search">
</form>
```

**Configuration**:
- `data-search-delay-value`: Custom delay (default: 300ms)
- `data-search-url-value`: Custom search URL

---

### 2. Filter Controller (`filter_controller.js`)
**Purpose**: Auto-submit filters when selections change

**Features**:
- Automatically submits form when filter values change
- Small delay (100ms) to allow multiple selections
- Loading indicators during submission
- Can be disabled with `data-filter-auto-submit-value="false"`

**Usage**:
```erb
<form data-controller="filter" data-action="submit->filter#submit">
  <select data-action="change->filter#change">
    <option>Filter 1</option>
  </select>
</form>
```

---

### 3. Collapsible Controller (`collapsible_controller.js`)
**Purpose**: Toggle visibility of content sections

**Features**:
- Smooth expand/collapse animations
- Rotating icon indicator
- Remembers state during session
- Can be initially open or closed

**Usage**:
```erb
<div data-controller="collapsible" data-collapsible-open-value="true">
  <button data-action="click->collapsible#toggle">
    <svg data-collapsible-target="icon">...</svg>
  </button>
  <div data-collapsible-target="content">
    <!-- Collapsible content -->
  </div>
</div>
```

---

### 4. Sync Controller (`sync_controller.js`)
**Purpose**: Trigger manual sync with loading states

**Features**:
- Shows spinner during sync
- Displays success/error messages
- Disables button during operation
- Auto-refreshes page after success

**Usage**:
```erb
<div data-controller="sync">
  <button
    data-sync-target="button"
    data-url="/sync/pull_requests"
    data-method="POST"
    data-action="click->sync#trigger">
    <span data-sync-target="spinner" class="hidden">Loading...</span>
    Sync Now
  </button>
  <div data-sync-target="status"></div>
</div>
```

---

### 5. Auto Refresh Controller (`auto_refresh_controller.js`)
**Purpose**: Periodically refresh content using Turbo Streams

**Features**:
- Configurable refresh interval
- Uses Turbo Streams for partial updates
- Stops when component disconnects
- Can refresh specific URL or reload page

**Usage**:
```erb
<div data-controller="auto-refresh"
     data-auto-refresh-interval-value="30000"
     data-auto-refresh-url-value="/sync/status">
  <!-- Auto-refreshing content -->
</div>
```

---

## Turbo Features

### Turbo Frames
Used for seamless page updates without full reload:

1. **Search Results** (`search_results`)
   - Updates only search results section
   - Preserves search form state

2. **Individual PR Details** (could be added)
   - Inline PR expansion
   - Lazy loading of comments

**Example**:
```erb
<%= turbo_frame_tag "search_results" do %>
  <div class="results">
    <!-- Search results here -->
  </div>
<% end %>
```

### Turbo Streams
For real-time updates (future enhancement):

- Live sync progress updates
- Real-time comment additions
- Background job status updates

**Example**:
```ruby
# In controller
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: turbo_stream.update("stats", partial: "stats")
  end
end
```

---

## CSS Animations

Custom animations in `app/assets/stylesheets/stimulus.css`:

1. **Collapsible Transitions**: Smooth expand/collapse
2. **Spinner Animation**: Rotating loading indicator
3. **Fade In**: Content appears smoothly
4. **Slide Down**: Status messages animate in
5. **Search Highlighting**: Yellow background for matches

---

## User Experience Improvements

### 1. Search Page
- ✅ Debounced live search (no "Search" button needed)
- ✅ Results update without page reload
- ✅ Highlighted search terms in results

### 2. Pull Requests Page
- ✅ Auto-submit filters on change
- ✅ Sync button with loading state
- ✅ Collapsible comments section

### 3. Insights Page
- ✅ Auto-submit type filter
- ✅ Generate insights with loading indicator

### 4. Dashboard
- ✅ Collapsible sections (Recent PRs, Tags, Insights)
- ✅ Smooth animations
- ✅ Could add auto-refresh for live stats

---

## Testing Stimulus Controllers

### In Browser Console:

```javascript
// Get controller instance
const controller = application.getControllerForElementAndIdentifier(
  document.querySelector('[data-controller="search"]'),
  'search'
)

// Call methods
controller.search()
controller.clear()
```

### Manual Testing:

1. **Search**: Type in search box → Results appear after 300ms
2. **Filter**: Change dropdown → Form auto-submits
3. **Collapsible**: Click header → Content expands/collapses
4. **Sync**: Click button → Shows spinner → Success message → Page reloads

---

## Future Enhancements

### Phase 8+:
1. **Turbo Streams**:
   - Real-time sync progress
   - Live comment updates
   - Background job notifications

2. **More Stimulus Controllers**:
   - `clipboard_controller.js` - Copy PR links
   - `modal_controller.js` - Inline PR preview
   - `toast_controller.js` - Toast notifications
   - `keyboard_controller.js` - Keyboard shortcuts

3. **Progressive Enhancement**:
   - Offline support
   - Optimistic UI updates
   - Background sync

4. **Advanced Features**:
   - Drag-and-drop PR organization
   - Inline editing of tags
   - Real-time collaboration

---

## Performance Considerations

1. **Debouncing**: Prevents excessive API calls (search, filters)
2. **Turbo Frames**: Reduces data transfer by updating only changed sections
3. **CSS Animations**: Hardware-accelerated transforms
4. **Lazy Loading**: Only load comments when needed
5. **Auto-refresh**: Smart intervals (30s default, can be increased)

---

## Browser Compatibility

All features work on modern browsers:
- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile Safari/Chrome

Graceful degradation: Forms still work without JavaScript.

---

## Development Tips

### Debugging Stimulus:
```javascript
// Enable debug mode
application.debug = true

// View all controllers
application.controllers.forEach(c => console.log(c.identifier, c))
```

### Testing Turbo:
```javascript
// Disable Turbo temporarily
Turbo.session.drive = false

// View Turbo cache
Turbo.cache.keys()
```

---

## Conclusion

The Hotwire/Stimulus implementation provides:
- ✅ Smooth, app-like user experience
- ✅ No full page reloads for most interactions
- ✅ Progressive enhancement
- ✅ Maintainable, organized JavaScript
- ✅ Fast, responsive interface

Next step: Add authentication (Phase 9)
