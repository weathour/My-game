extends RefCounted
## Presentation tiers are independent of story importance and reward eligibility.
const TIERS := {
	"common": {"label":"普通", "field":Color("244f79"), "footer":Color("163750"), "edge":Color("81b7e1")},
	"rare": {"label":"稀有", "field":Color("594571"), "footer":Color("352d46"), "edge":Color("c7a4e5")},
	"legendary": {"label":"传说", "field":Color("8c5728"), "footer":Color("51371f"), "edge":Color("f1c574")},
	"hero": {"label":"主角", "field":Color("713b35"), "footer":Color("432823"), "edge":Color("e9b18d")}
}

static func style(key: String) -> Dictionary:
	return TIERS.get(key, TIERS.common)
