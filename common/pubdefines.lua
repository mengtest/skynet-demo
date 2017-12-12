SPROTO_INDEX = 1
BASE_PACKAGE = "BasePackage"

GAME_CFG = {
    ["protocol_type"] = "sproto" --json or sproto
}

function IsSprotoCompression()
    return GAME_CFG.protocol_type == "sproto"
end

function IsJsonCompression()
    return GAME_CFG.protocol_type == "json"
end