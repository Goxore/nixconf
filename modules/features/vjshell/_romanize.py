import re
import sys
import unicodedata

KANA = re.compile(r"[぀-ゟ゠-ヿ]")
HAN = re.compile(r"[㐀-䶿一-鿿]")

VOWEL_KANA = {"a": "あ", "i": "い", "u": "う", "e": "え", "o": "お"}
SOKUON = ("っ", "ッ")

PARTICLE = "助詞"
SUFFIX = "接尾辞"
AUXILIARY = "助動詞"
VERBAL = ("動詞", "助動詞", "形容詞", "形状詞")

COPULA = ("だ", "です", "でし", "だっ")
CONJUNCTIVE = ("て", "で")


def body_script(lines):
    body = "".join(lines)
    if KANA.search(body):
        return "ja"
    if HAN.search(body):
        return "zh"
    return ""


def pos_of(token):
    return getattr(token.feature, "pos1", "") or ""


def reading_of(token):
    order = ("pron", "kana") if pos_of(token) == PARTICLE else ("kana", "pron")
    for name in order:
        value = getattr(token.feature, name, None)
        if value and value != "*" and KANA.search(value):
            return value
    return None


def attaches(token, previous):
    pos = pos_of(token)
    if pos == SUFFIX:
        return True
    if pos == AUXILIARY:
        return token.surface not in COPULA or previous == "動詞"
    if pos == PARTICLE and token.surface in CONJUNCTIVE:
        return previous is not None and previous in VERBAL
    return False


def to_romaji(kana):
    import jaconv

    hira = jaconv.kata2hira(kana)
    extended = ""
    for char in hira:
        if char == "ー" and extended:
            previous = jaconv.kana2alphabet(extended[-1])
            vowel = previous[-1] if previous and previous[-1] in VOWEL_KANA else "u"
            extended += VOWEL_KANA[vowel]
        else:
            extended += char
    return jaconv.kana2alphabet(extended)


def romanize_ja(lines):
    import fugashi

    tagger = fugashi.Tagger()
    out = []
    for line in lines:
        pieces = []
        previous = None
        for token in tagger(line):
            reading = reading_of(token)
            chunk = reading if reading else token.surface
            joinable = pieces and pieces[-1][0]
            if joinable and (pieces[-1][1].endswith(SOKUON) or attaches(token, previous)):
                pieces[-1] = (True, pieces[-1][1] + chunk)
            else:
                pieces.append((reading is not None, chunk))
            previous = pos_of(token)
        out.append(" ".join(to_romaji(text) if kana else text for kana, text in pieces).strip())
    return out


def romanize_zh(lines):
    from pypinyin import Style, pinyin

    return [" ".join(p[0] for p in pinyin(line, style=Style.TONE)).strip() for line in lines]


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()
    lines = unicodedata.normalize("NFC", source).split("\n")
    trailing = bool(lines) and lines[-1] == ""
    if trailing:
        lines.pop()

    script = body_script(lines)
    if script == "ja":
        lines = romanize_ja(lines)
    elif script == "zh":
        lines = romanize_zh(lines)

    sys.stdout.write("\n".join(lines) + ("\n" if trailing else ""))


main()
