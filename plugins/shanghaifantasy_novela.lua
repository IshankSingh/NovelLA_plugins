id       = "shanghaifantasy"
name     = "Shanghai Fantasy"
version  = "1.0.1"
baseUrl  = "https://shanghaifantasy.com"
language = "en"

local function absUrl(href)
  if not href or href == "" then return "" end
  if string_starts_with(href, "http") then return href end
  if string_starts_with(href, "//") then return "https:" .. href end
  return url_resolve(baseUrl, href)
end

local function clean(text)
  if not text then return "" end
  return string_clean(text)
end

local function fetch(url)
  local r = http_get(url)
  if r and r.success then return r end
  return nil
end

local function parseApiNovels(body)
  local data = json_parse(body)
  if not data then return {} end
  local items = {}
  for _, item in ipairs(data) do
    local title = clean(item.title)
    local path = absUrl(item.permalink)
    if title ~= "" and path ~= "" then
      table.insert(items, {
        title = title,
        url = path,
        cover = absUrl(item.novelImage)
      })
    end
  end
  return items
end

function getCatalogList(index)
  local page = (index or 0) + 1
  local url = baseUrl .. "/wp-json/fiction/v1/novels/?novelstatus=&term=&page=" ..
              tostring(page) .. "&orderBy=&order=&query="
  local r = fetch(url)
  if not r then return { items = {}, hasNext = false } end
  local items = parseApiNovels(r.body)
  return { items = items, hasNext = #items > 0 }
end

function getCatalogSearch(index, query)
  local page = (index or 0) + 1
  local url = baseUrl .. "/wp-json/fiction/v1/novels/?novelstatus=&term=&page=" ..
              tostring(page) .. "&orderBy=&order=&query=" .. url_encode(query)
  local r = fetch(url)
  if not r then return { items = {}, hasNext = false } end
  local items = parseApiNovels(r.body)
  return { items = items, hasNext = #items > 0 }
end

function getBookTitle(bookUrl)
  local r = fetch(bookUrl)
  if not r then return nil end
  local details = html_select_first(r.body, "div:has(>#likebox)")
  if not details then return nil end
  local title = html_select_first(details.html, "p.text-lg")
  return title and clean(title.text) or nil
end

function getBookCoverImageUrl(bookUrl)
  local r = fetch(bookUrl)
  if not r then return nil end
  local details = html_select_first(r.body, "div:has(>#likebox)")
  if not details then return nil end
  local img = html_select_first(details.html, "img")
  local src = img and img.src or ""
  return src ~= "" and absUrl(src) or nil
end

function getBookDescription(bookUrl)
  local r = fetch(bookUrl)
  if not r then return "" end
  local el = html_select_first(r.body, "div[x-show='activeTab===\"Synopsis\"']")
  if not el then el = html_select_first(r.body, "div[x-show='activeTab==\"Synopsis\"']") end
  return el and string_trim(el.text) or ""
end

function getBookGenres(bookUrl)
  local r = fetch(bookUrl)
  if not r then return {} end
  local details = html_select_first(r.body, "div:has(>#likebox)")
  if not details then return {} end
  local genres = {}
  for _, el in ipairs(html_select(details.html, "div.flex > span > a") or {}) do
    local genre = clean(el.text)
    if genre ~= "" then table.insert(genres, genre) end
  end
  return genres
end

function getChapterList(bookUrl)
  local r = fetch(bookUrl)
  if not r then return {} end
  local category = html_attr(r.body, "ul#chapterList", "data-cat")
  if not category or category == "" then return {} end

  local chapters = {}
  local page = 1
  local perPage = 100

  while true do
    local url = baseUrl .. "/wp-json/fiction/v1/chapters?category=" ..
                url_encode(category) .. "&order=asc&page=" ..
                tostring(page) .. "&per_page=" .. tostring(perPage)
    local cr = fetch(url)
    if not cr then break end
    local data = json_parse(cr.body)
    if not data or #data == 0 then break end

    for _, ch in ipairs(data) do
      local title = clean(ch.title)
      if title == "" then title = "Chapter" end
      if ch.locked then title = "🔒 " .. title end
      if ch.permalink and ch.permalink ~= "" then
        table.insert(chapters, { title = title, url = absUrl(ch.permalink) })
      end
    end

    if #data < perPage then break end
    page = page + 1
  end
  return chapters
end

function getChapterText(url)
  local r = fetch(url)
  if not r then return "" end
  
  local content = html_select_first(r.body, "div.contenta")
  if not content then return "" end

  local cleaned = html_remove(content.html, "script")
  cleaned = html_remove(cleaned, ".ai-viewports")
  cleaned = html_remove(cleaned, ".ai-viewport-1")
  cleaned = html_remove(cleaned, ".ai-viewport-2")
  cleaned = html_remove(cleaned, ".ai-viewport-3")
  cleaned = html_remove(cleaned, ".mycred-sell-this-wrapper")
  return cleaned
end