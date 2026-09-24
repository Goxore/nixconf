pragma Singleton

import QtQuick
import Quickshell
import qs.Widgets

Singleton {
    id: root

    readonly property var languages: ({
            af: "Afrikaans",
            ak: "Twi",
            am: "Amharic",
            ar: "Arabic",
            as: "Assamese",
            ay: "Aymara",
            az: "Azerbaijani",
            be: "Belarusian",
            bg: "Bulgarian",
            bho: "Bhojpuri",
            bm: "Bambara",
            bn: "Bengali",
            bs: "Bosnian",
            ca: "Catalan",
            ceb: "Cebuano",
            ckb: "Sorani Kurdish",
            co: "Corsican",
            cs: "Czech",
            cy: "Welsh",
            da: "Danish",
            de: "German",
            doi: "Dogri",
            dv: "Dhivehi",
            ee: "Ewe",
            el: "Greek",
            en: "English",
            eo: "Esperanto",
            es: "Spanish",
            et: "Estonian",
            eu: "Basque",
            fa: "Persian",
            fi: "Finnish",
            fr: "French",
            fy: "Frisian",
            ga: "Irish",
            gd: "Scots Gaelic",
            gl: "Galician",
            gn: "Guarani",
            gom: "Konkani",
            gu: "Gujarati",
            ha: "Hausa",
            haw: "Hawaiian",
            he: "Hebrew",
            hi: "Hindi",
            hmn: "Hmong",
            hr: "Croatian",
            ht: "Haitian Creole",
            hu: "Hungarian",
            hy: "Armenian",
            id: "Indonesian",
            ig: "Igbo",
            ilo: "Ilocano",
            is: "Icelandic",
            it: "Italian",
            ja: "Japanese",
            jv: "Javanese",
            ka: "Georgian",
            kk: "Kazakh",
            km: "Khmer",
            kn: "Kannada",
            ko: "Korean",
            kri: "Krio",
            ku: "Kurdish",
            ky: "Kyrgyz",
            la: "Latin",
            lb: "Luxembourgish",
            lg: "Luganda",
            ln: "Lingala",
            lo: "Lao",
            lt: "Lithuanian",
            lus: "Mizo",
            lv: "Latvian",
            mai: "Maithili",
            mg: "Malagasy",
            mi: "Maori",
            mk: "Macedonian",
            ml: "Malayalam",
            mn: "Mongolian",
            mni: "Meiteilon",
            mr: "Marathi",
            ms: "Malay",
            mt: "Maltese",
            my: "Burmese",
            ne: "Nepali",
            nl: "Dutch",
            no: "Norwegian",
            nso: "Sepedi",
            ny: "Chichewa",
            om: "Oromo",
            or: "Odia",
            pa: "Punjabi",
            pl: "Polish",
            ps: "Pashto",
            pt: "Portuguese",
            qu: "Quechua",
            ro: "Romanian",
            ru: "Russian",
            rw: "Kinyarwanda",
            sa: "Sanskrit",
            sd: "Sindhi",
            si: "Sinhala",
            sk: "Slovak",
            sl: "Slovenian",
            sm: "Samoan",
            sn: "Shona",
            so: "Somali",
            sq: "Albanian",
            sr: "Serbian",
            st: "Sesotho",
            su: "Sundanese",
            sv: "Swedish",
            sw: "Swahili",
            ta: "Tamil",
            te: "Telugu",
            tg: "Tajik",
            th: "Thai",
            ti: "Tigrinya",
            tk: "Turkmen",
            tl: "Filipino",
            tr: "Turkish",
            ts: "Tsonga",
            tt: "Tatar",
            ug: "Uyghur",
            uk: "Ukrainian",
            ur: "Urdu",
            uz: "Uzbek",
            vi: "Vietnamese",
            xh: "Xhosa",
            yi: "Yiddish",
            yo: "Yoruba",
            zh: "Chinese",
            zu: "Zulu"
        })

    property string engine: "bing"

    property string sourceLang: ""
    property string targetLang: ""
    property string pending: ""
    property string result: ""
    property string translated: ""
    readonly property bool loading: translation.loading

    readonly property bool recognized: targetLang !== ""

    readonly property string sourceName: name(sourceLang)
    readonly property string targetName: name(targetLang)
    readonly property string pair: sourceName + " → " + targetName

    function name(code) {
        return languages[code] || code.toUpperCase();
    }

    function known(code) {
        return languages[code] !== undefined;
    }

    function parse(query) {
        const match = /^([A-Z]{2})([A-Z]{2})\s+(\S[\s\S]*)$/.exec(query) || /^([A-Z]{2,3})-([A-Z]{2,3})\s+(\S[\s\S]*)$/.exec(query);
        if (!match)
            return null;

        const source = match[1].toLowerCase();
        const target = match[2].toLowerCase();
        if (!known(source) || !known(target))
            return null;

        return {
            sourceLang: source,
            targetLang: target,
            text: match[3]
        };
    }

    function update(query) {
        const parsed = parse(query);
        if (!parsed) {
            clear();
            return;
        }

        result = "";
        translated = "";

        sourceLang = parsed.sourceLang;
        targetLang = parsed.targetLang;
        pending = parsed.text;
        translation.request = {
            command: ["trans", "-e", engine, "-b", "-s", sourceLang, "-t", targetLang, pending],
            context: pending
        };
    }

    function clear() {
        translation.request = null;
        sourceLang = "";
        targetLang = "";
        pending = "";
        result = "";
        translated = "";
    }

    RequestProcess {
        id: translation
        delay: 400
        onFinished: (code, output, query) => {
            root.result = code === 0 ? output.trim() : "";
            root.translated = query;
        }
    }
}
