extends RefCounted
class_name OxenWarI18n

const TEXTS := {
	"az": {
		"brand":"OXENWAR", "subtitle":"OYUNA QOŞUL", "email":"E-poçt", "password":"Şifrə",
		"display_name":"Görünən ad", "username":"Oyunçu adı", "login":"DAXİL OL", "register":"QEYDİYYAT",
		"language":"Dil", "play":"OYNA", "friends":"DOSTLAR", "character":"PERSONAJ",
		"search":"Oyunçu axtar", "add":"ƏLAVƏ ET", "requests":"DOSTLUQ SORĞULARI",
		"accept":"QƏBUL ET", "reject":"RƏDD ET", "save":"YADDA SAXLA", "logout":"ÇIXIŞ",
		"online":"ONLAYN", "offline":"OFFLAYN", "free":"PULSUZ", "choose_color":"Rəng",
		"choose_outfit":"Geyim", "start":"OYUNA BAŞLA", "auth_hint":"Davam etmək üçün hesabına daxil ol.",
		"login_ok":"Giriş uğurludur.", "register_ok":"Hesab yaradıldı.", "confirm_email":"E-poçtunu təsdiqlə, sonra daxil ol.",
		"no_results":"Oyunçu tapılmadı.", "pending":"Gözləyir", "error":"Xəta"
	},
	"en": {
		"brand":"OXENWAR", "subtitle":"ENTER THE ARENA", "email":"Email", "password":"Password",
		"display_name":"Display name", "username":"Player name", "login":"SIGN IN", "register":"CREATE ACCOUNT",
		"language":"Language", "play":"PLAY", "friends":"FRIENDS", "character":"CHARACTER",
		"search":"Search players", "add":"ADD FRIEND", "requests":"FRIEND REQUESTS",
		"accept":"ACCEPT", "reject":"DECLINE", "save":"SAVE", "logout":"SIGN OUT",
		"online":"ONLINE", "offline":"OFFLINE", "free":"FREE", "choose_color":"Color",
		"choose_outfit":"Outfit", "start":"START GAME", "auth_hint":"Sign in to continue.",
		"login_ok":"Signed in.", "register_ok":"Account created.", "confirm_email":"Confirm your email, then sign in.",
		"no_results":"No players found.", "pending":"Pending", "error":"Error"
	},
	"tr": {
		"brand":"OXENWAR", "subtitle":"ARENAYA KATIL", "email":"E-posta", "password":"Şifre",
		"display_name":"Görünen ad", "username":"Oyuncu adı", "login":"GİRİŞ YAP", "register":"KAYIT OL",
		"language":"Dil", "play":"OYNA", "friends":"ARKADAŞLAR", "character":"KARAKTER",
		"search":"Oyuncu ara", "add":"ARKADAŞ EKLE", "requests":"ARKADAŞLIK İSTEKLERİ",
		"accept":"KABUL ET", "reject":"REDDET", "save":"KAYDET", "logout":"ÇIKIŞ",
		"online":"ÇEVRİMİÇİ", "offline":"ÇEVRİMDIŞI", "free":"ÜCRETSİZ", "choose_color":"Renk",
		"choose_outfit":"Kıyafet", "start":"OYUNA BAŞLA", "auth_hint":"Devam etmek için giriş yap.",
		"login_ok":"Giriş başarılı.", "register_ok":"Hesap oluşturuldu.", "confirm_email":"E-postanı doğrula, sonra giriş yap.",
		"no_results":"Oyuncu bulunamadı.", "pending":"Bekliyor", "error":"Hata"
	},
	"ru": {
		"brand":"OXENWAR", "subtitle":"ВОЙТИ НА АРЕНУ", "email":"Эл. почта", "password":"Пароль",
		"display_name":"Отображаемое имя", "username":"Имя игрока", "login":"ВОЙТИ", "register":"СОЗДАТЬ АККАУНТ",
		"language":"Язык", "play":"ИГРАТЬ", "friends":"ДРУЗЬЯ", "character":"ПЕРСОНАЖ",
		"search":"Поиск игроков", "add":"ДОБАВИТЬ", "requests":"ЗАПРОСЫ В ДРУЗЬЯ",
		"accept":"ПРИНЯТЬ", "reject":"ОТКЛОНИТЬ", "save":"СОХРАНИТЬ", "logout":"ВЫЙТИ",
		"online":"В СЕТИ", "offline":"НЕ В СЕТИ", "free":"БЕСПЛАТНО", "choose_color":"Цвет",
		"choose_outfit":"Одежда", "start":"НАЧАТЬ ИГРУ", "auth_hint":"Войдите, чтобы продолжить.",
		"login_ok":"Вход выполнен.", "register_ok":"Аккаунт создан.", "confirm_email":"Подтвердите почту, затем войдите.",
		"no_results":"Игроки не найдены.", "pending":"Ожидание", "error":"Ошибка"
	}
}

static func tr(key: String, locale: String) -> String:
	var language: Dictionary = TEXTS.get(locale, TEXTS["en"])
	return str(language.get(key, TEXTS["en"].get(key, key)))
