local L_enUS = {
    -- Add localization keys and their English values here
    ["TITLE_KEY"] = "Module Title",
    ["DETAILED_CONTENT_KEY"] = "This is a detailed description of the module.",
}

local L_trTR = {
    -- Add localization keys and their Turkish values here
    ["TITLE_KEY"] = "Modül Başlığı",
    ["DETAILED_CONTENT_KEY"] = "Bu modülün detaylı açıklamasıdır.",
}

function EasyLife:L(key)
    return L_enUS[key] or L_trTR[key] or key
end