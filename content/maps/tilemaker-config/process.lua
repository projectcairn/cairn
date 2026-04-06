-- Tilemaker processing script for Cairn GB tiles
-- OpenMapTiles-compatible layer schema

-- Attribute keys
node_keys = {"place", "name", "amenity", "shop", "tourism", "natural", "highway"}

-- ---------------------------------------------------------------------------
-- Helper: clamp zoom
-- ---------------------------------------------------------------------------
function SetMinZoomByArea(way, minzoom)
    local dominated = way:Area()
    if dominated > 0 then
        if     dominated > 2000000000 then way:MinZoom(0)
        elseif dominated > 200000000  then way:MinZoom(3)
        elseif dominated > 20000000   then way:MinZoom(5)
        elseif dominated > 2000000    then way:MinZoom(7)
        elseif dominated > 200000     then way:MinZoom(9)
        elseif dominated > 20000      then way:MinZoom(11)
        else                                way:MinZoom(minzoom)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Process nodes (places, POIs)
-- ---------------------------------------------------------------------------
function node_function(node)
    local place = node:Find("place")
    if place ~= "" then
        node:Layer("place", false)
        node:Attribute("class", place)
        local name = node:Find("name")
        if name ~= "" then node:Attribute("name", name) end
        local pop = tonumber(node:Find("population") or "0") or 0
        if pop > 0 then node:AttributeNumeric("population", pop) end

        if     place == "city"    then node:MinZoom(3)
        elseif place == "town"    then node:MinZoom(6)
        elseif place == "village" then node:MinZoom(9)
        elseif place == "hamlet"  then node:MinZoom(11)
        elseif place == "suburb"  then node:MinZoom(10)
        else                           node:MinZoom(12)
        end
        return
    end

    local amenity = node:Find("amenity")
    local shop = node:Find("shop")
    local tourism = node:Find("tourism")
    if amenity ~= "" or shop ~= "" or tourism ~= "" then
        node:Layer("poi", false)
        node:MinZoom(12)
        local name = node:Find("name")
        if name ~= "" then node:Attribute("name", name) end
        if amenity ~= "" then node:Attribute("class", amenity)
        elseif shop ~= "" then node:Attribute("class", shop)
        elseif tourism ~= "" then node:Attribute("class", tourism) end
    end
end

-- ---------------------------------------------------------------------------
-- Process ways (areas + lines)
-- ---------------------------------------------------------------------------
function way_function(way)
    local highway = way:Find("highway")
    local waterway = way:Find("waterway")
    local natural = way:Find("natural")
    local landuse = way:Find("landuse")
    local leisure = way:Find("leisure")
    local building = way:Find("building")
    local boundary = way:Find("boundary")
    local water = way:Find("water")
    local name = way:Find("name")

    -- Water polygons
    if natural == "water" or water ~= "" or landuse == "reservoir" or landuse == "basin" then
        way:Layer("water", true)
        way:Attribute("class", water ~= "" and water or natural)
        if name ~= "" then way:Attribute("name", name) end
        SetMinZoomByArea(way, 10)
        return
    end

    -- Waterways (lines)
    if waterway == "river" or waterway == "canal" then
        way:Layer("waterway", false)
        way:Attribute("class", waterway)
        if name ~= "" then way:Attribute("name", name) end
        if waterway == "river" then way:MinZoom(8) else way:MinZoom(10) end
        return
    end
    if waterway == "stream" or waterway == "drain" or waterway == "ditch" then
        way:Layer("waterway", false)
        way:Attribute("class", waterway)
        way:MinZoom(12)
        return
    end

    -- Landcover (forests, grass, farmland)
    if natural == "wood" or natural == "scrub" or landuse == "forest" then
        way:Layer("landcover", true)
        way:Attribute("class", "wood")
        SetMinZoomByArea(way, 10)
        return
    end
    if natural == "grassland" or landuse == "grass" or landuse == "meadow" or landuse == "farmland" then
        way:Layer("landcover", true)
        way:Attribute("class", landuse ~= "" and landuse or natural)
        SetMinZoomByArea(way, 11)
        return
    end
    if natural == "heath" or natural == "wetland" or natural == "beach" then
        way:Layer("landcover", true)
        way:Attribute("class", natural)
        SetMinZoomByArea(way, 10)
        return
    end

    -- Landuse
    if landuse == "residential" or landuse == "industrial" or landuse == "commercial" or
       landuse == "retail" or landuse == "cemetery" then
        way:Layer("landuse", true)
        way:Attribute("class", landuse)
        SetMinZoomByArea(way, 11)
        return
    end

    -- Parks
    if leisure == "park" or leisure == "garden" or leisure == "nature_reserve" or
       boundary == "national_park" then
        way:Layer("park", true)
        way:Attribute("class", leisure ~= "" and leisure or "national_park")
        if name ~= "" then way:Attribute("name", name) end
        SetMinZoomByArea(way, 9)
        return
    end

    -- Boundaries (admin)
    if boundary == "administrative" then
        local admin_level = tonumber(way:Find("admin_level") or "0") or 0
        if admin_level >= 2 and admin_level <= 8 then
            way:Layer("boundary", false)
            way:AttributeNumeric("admin_level", admin_level)
            if admin_level <= 4 then way:MinZoom(0)
            elseif admin_level <= 6 then way:MinZoom(5)
            else way:MinZoom(8) end
        end
        return
    end

    -- Transportation (roads)
    if highway ~= "" then
        way:Layer("transportation", false)
        way:Attribute("class", highway)
        if name ~= "" then way:Attribute("name", name) end
        local ref = way:Find("ref")
        if ref ~= "" then way:Attribute("ref", ref) end
        local bridge = way:Find("bridge")
        if bridge == "yes" then way:AttributeBoolean("bridge", true) end
        local tunnel = way:Find("tunnel")
        if tunnel == "yes" then way:AttributeBoolean("tunnel", true) end

        if     highway == "motorway" or highway == "motorway_link" then way:MinZoom(4)
        elseif highway == "trunk" or highway == "trunk_link"       then way:MinZoom(5)
        elseif highway == "primary" or highway == "primary_link"   then way:MinZoom(7)
        elseif highway == "secondary" or highway == "secondary_link" then way:MinZoom(8)
        elseif highway == "tertiary" or highway == "tertiary_link" then way:MinZoom(10)
        elseif highway == "residential" or highway == "unclassified" then way:MinZoom(12)
        elseif highway == "service" or highway == "track"          then way:MinZoom(13)
        elseif highway == "path" or highway == "footway" or
               highway == "cycleway" or highway == "bridleway"     then way:MinZoom(13)
        else way:MinZoom(14) end
        return
    end

    -- Buildings
    if building ~= "" then
        way:Layer("building", true)
        way:MinZoom(13)
        return
    end
end
