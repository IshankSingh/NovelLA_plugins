id       = "shanghaifantasy"
name     = "Shanghai Fantasy"
version  = "1.0.0"
baseUrl  = "https://shanghaifantasy.com"
language = "en"
icon     = "https://raw.githubusercontent.com/HnDK0/external-sources/main/icons/novelfire.png"

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

local function clean(s)
  if not s then return "" end
  return string_trim(string_clean(s))
end

local function api(url)
  local r = http_get(url)
  if not r.success then return nil end
  return r
end

local function parseNovelCards(body)
  local items = {}
  for _, card in ipairs(html_select(body, ".novel-list > .novel-item")) do
    local titleEl = html_select_first(card.html, ".novel-title")
    local linkEl  = html_select_first(card.html, ".novel-title a")
    local cover   = html_attr(card.html, "img", "data-src")
    if cover == "" then cover = html_attr(card.html, "img", "src") end
    if titleEl and linkEl then
      table.insert(items, {
        title = clean(titleEl.text),
        url   = absUrl(linkEl.href),
        cover = absUrl(cover)
      })
    end
  end
  return items
end

function getCatalogList(index)
  local page = index + 1
  local url = baseUrl .. "/wp-json/fiction/v1/novels/?novelstatus=&term=&page=" ..
              tostring(page) .. "&orderBy=&order=&query="
  local r = api(url)
  if not r then return { items = {}, hasNext = false } end
  local data = json_parse(r.body)
  local items = {}
  if data then
    for _, item in ipairs(data) do
      table.insert(items, {
        title = clean(item.title),
        url = absUrl(item.permalink),
        cover = absUrl(item.novelImage)
      })
    end
  end
  return { items = items, hasNext = #items > 0 }
end

function getCatalogSearch(index, query)
  local page = index + 1
  local url = baseUrl .. "/wp-json/fiction/v1/novels/?novelstatus=&term=&page=" ..
              tostring(page) .. "&orderBy=&order=&query=" .. url_encode(query)
  local r = api(url)
  if not r then return { items = {}, hasNext = false } end
  local data = json_parse(r.body)
  local items = {}
  if data then
    for _, item in ipairs(data) do
      table.insert(items, {
        title = clean(item.title),
        url = absUrl(item.permalink),
        cover = absUrl(item.novelImage)
      })
    end
  end
  return { items = items, hasNext = #items > 0 }
end

function getBookTitle(bookUrl)
  local r = api(bookUrl)
  if not r then return nil end
  local el = html_select_first(r.body, "div:has(>#likebox) p.text-lg")
  if el then return clean(el.text) end
  el = html_select_first(r.body, "h1")
  return el and clean(el.text) or nil
end

function getBookCoverImageUrl(bookUrl)
  local r = api(bookUrl)
  if not r then return nil end
  local el = html_select_first(r.body, "div:has(>#likebox) > img")
  local src = el and html_attr(el.html, "img", "src") or ""
  if src == "" then src = html_attr(r.body, "meta[property='og:image']", "content") end
  return src ~= "" and absUrl(src) or nil
end

function getBookDescription(bookUrl)
  local r = api(bookUrl)
  if not r then return nil end
  local el = html_select_first(r.body, "div[x-show=activeTab=='Synopsis']")
  if not el then el = html_select_first(r.body, "[x-show=\"activeTab==='Synopsis'\"]") end
  return el and clean(el.text) or nil
end

function getBookGenres(bookUrl)
  local r = api(bookUrl)
  if not r then return {} end
  local genres = {}
  for _, a in ipairs(html_select(r.body, "div:has(>#likebox) > div > div.flex > span > a")) do
    local g = clean(a.text)
    if g ~= "" then table.insert(genres, g) end
  end
  return genres
end

function getChapterList(bookUrl)
  local r = api(bookUrl)
  if not r then return {} end

  local category = html_attr(r.body, "ul#chapterList", "data-cat")
  if not category or category == "" then return {} end

  local chapters = {}
  local page = 1
  local MAX_PAGE_CHAPTERS = 5000

  while true do
    local url = baseUrl .. "/wp-json/fiction/v1/chapters?category=" ..
                url_encode(category) .. "&order=asc&page=" .. tostring(page) ..
                "&per_page=" .. tostring(MAX_PAGE_CHAPTERS)
    local cr = api(url)
    if not cr then break end

    local data = json_parse(cr.body)
    if not data or #data == 0 then break end

    for _, ch in ipairs(data) do
      local title = clean(ch.title)
      if title == "" then title = "Chapter" end
      table.insert(chapters, {
        title = title,
        url = absUrl(ch.permalink)
      })
    end

    if #data < MAX_PAGE_CHAPTERS then break end
    page = page + 1
  end

  return chapters
end

function getChapterText(html, url)
  local cleaned = html_remove(
    html,
    "script", "style", "nav",
    ".ai-viewports", ".ai-viewport-1", ".ai-viewport-2", ".ai-viewport-3",
    ".ads", ".advertisement", ".comments", ".disqus"
  )

  local el = html_select_first(cleaned, "div.contenta")
  if not el then
    el = html_select_first(cleaned, ".contenta")
  end
  if not el then return "" end

  local text = html_text(el.html)
  text = string_normalize(text)
  text = regex_replace(text, "(?i)shanghaifantasy\\.com.*?\\n", "")
  text = string_trim(text)
  return text
end

function getFilterList()
  return {}
end
