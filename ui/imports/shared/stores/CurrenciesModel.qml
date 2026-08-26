import QtQuick

ListModel {
    ListElement {
        key: "usd"
        shortName: "USD"
        name: qsTr("US Dollars")
        symbol: "$"
        category: ""
        imageSource: "../../assets/twemoji/svg/1f1fa-1f1f8.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "gbp"
        shortName: "GBP"
        name: qsTr("British Pound")
        symbol: "£"
        category: ""
        imageSource: "../../assets/twemoji/svg/1f1ec-1f1e7.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "eur"
        shortName: "EUR"
        name: qsTr("Euros")
        symbol: "€"
        category: ""
        imageSource: "../../assets/twemoji/svg/1f1ea-1f1fa.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "rub"
        shortName: "RUB"
        name: qsTr("Russian ruble")
        symbol: "₽"
        category: ""
        imageSource: "../../assets/twemoji/svg/1f1f7-1f1fa.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "krw"
        shortName: "KRW"
        name: qsTr("South Korean won")
        symbol: "₩"
        category: ""
        imageSource: "../../assets/twemoji/svg/1f1f0-1f1f7.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "eth"
        shortName: "ETH"
        name: qsTr("Ethereum")
        symbol: "Ξ"
        category: qsTr("Tokens")
        imageSource: "../../assets/png/tokens/ETH.png"
        selected: false
        isToken: true
    }

    ListElement {
        key: "btc"
        shortName: "BTC"
        name: qsTr("Bitcoin")
        symbol: "฿"
        category: qsTr("Tokens")
        imageSource: "../../assets/png/tokens/WBTC.png"
        selected: false
        isToken: true
    }

    ListElement {
        key: "aed"
        shortName: "AED"
        name: qsTr("United Arab Emirates dirham")
        symbol: "د.إ"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e6-1f1ea.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "ars"
        shortName: "ARS"
        name: qsTr("Argentine peso")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e6-1f1f7.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "aud"
        shortName: "AUD"
        name: qsTr("Australian dollar")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e6-1f1fa.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "bdt"
        shortName: "BDT"
        name: qsTr("Bangladeshi taka")
        symbol: "Tk"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e7-1f1e9.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "bhd"
        shortName: "BHD"
        name: qsTr("Bahraini dinar")
        symbol: "BD"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e7-1f1ed.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "brl"
        shortName: "BRL"
        name: qsTr("Brazillian real")
        symbol: "R$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e7-1f1f7.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "cad"
        shortName: "CAD"
        name: qsTr("Canadian dollar")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e8-1f1e6.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "chf"
        shortName: "CHF"
        name: qsTr("Swiss franc")
        symbol: "CHF"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e8-1f1ed.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "clp"
        shortName: "CLP"
        name: qsTr("Chilean peso")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e8-1f1f1.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "cny"
        shortName: "CNY"
        name: qsTr("Chinese yuan")
        symbol: "¥"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e8-1f1f3.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "czk"
        shortName: "CZK"
        name: qsTr("Czech koruna")
        symbol: "Kč"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e8-1f1ff.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "dkk"
        shortName: "DKK"
        name: qsTr("Danish krone")
        symbol: "kr"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1e9-1f1f0.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "gel"
        shortName: "GEL"
        name: qsTr("Georgian lari")
        symbol: "₾"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ec-1f1ea.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "hkd"
        shortName: "HKD"
        name: qsTr("Hong Kong dollar")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ed-1f1f0.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "huf"
        shortName: "HUF"
        name: qsTr("Hungarian forint")
        symbol: "Ft"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ed-1f1fa.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "idr"
        shortName: "IDR"
        name: qsTr("Indonesian rupiah")
        symbol: "Rp"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ee-1f1e9.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "ils"
        shortName: "ILS"
        name: qsTr("Israeli new shekel")
        symbol: "₪"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ee-1f1f1.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "inr"
        shortName: "INR"
        name: qsTr("Indian rupee")
        symbol: "₹"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ee-1f1f3.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "jpy"
        shortName: "JPY"
        name: qsTr("Japanese yen")
        symbol: "¥"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ef-1f1f5.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "kwd"
        shortName: "KWD"
        name: qsTr("Kuwaiti dinar")
        symbol: "د.ك"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f0-1f1fc.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "lkr"
        shortName: "LKR"
        name: qsTr("Sri Lankan rupee")
        symbol: "₨"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f1-1f1f0.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "mxn"
        shortName: "MXN"
        name: qsTr("Mexican peso")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f2-1f1fd.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "myr"
        shortName: "MYR"
        name: qsTr("Malaysian ringgit")
        symbol: "RM"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f2-1f1fe.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "ngn"
        shortName: "NGN"
        name: qsTr("Nigerian naira")
        symbol: "₦"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f3-1f1ec.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "nok"
        shortName: "NOK"
        name: qsTr("Norwegian krone")
        symbol: "kr"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f3-1f1f4.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "nzd"
        shortName: "NZD"
        name: qsTr("New Zealand dollar")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f3-1f1ff.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "php"
        shortName: "PHP"
        name: qsTr("Philippine peso")
        symbol: "₱"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f5-1f1ed.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "pkr"
        shortName: "PKR"
        name: qsTr("Pakistani rupee")
        symbol: "₨"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f5-1f1f0.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "pln"
        shortName: "PLN"
        name: qsTr("Polish złoty")
        symbol: "zł"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f5-1f1f1.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "sar"
        shortName: "SAR"
        name: qsTr("Saudi riyal")
        symbol: "﷼"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f8-1f1e6.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "sek"
        shortName: "SEK"
        name: qsTr("Swedish krona")
        symbol: "kr"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f8-1f1ea.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "sgd"
        shortName: "SGD"
        name: qsTr("Singapore dollar")
        symbol: "$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f8-1f1ec.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "thb"
        shortName: "THB"
        name: qsTr("Thai baht")
        symbol: "฿"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f9-1f1ed.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "twd"
        shortName: "TWD"
        name: qsTr("New Taiwan dollar")
        symbol: "NT$"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f9-1f1fc.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "try"
        shortName: "TRY"
        name: qsTr("Turkish lira")
        symbol: "₺"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1f9-1f1f7.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "uah"
        shortName: "UAH"
        name: qsTr("Ukrainian hryvnia")
        symbol: "₴"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1fa-1f1e6.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "vnd"
        shortName: "VND"
        name: qsTr("Vietnamese đồng")
        symbol: "₫"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1fb-1f1f3.svg"
        selected: false
        isToken: false
    }

    ListElement {
        key: "zar"
        shortName: "ZAR"
        name: qsTr("South African rand")
        symbol: "R"
        category: qsTr("Other Fiat")
        imageSource: "../../assets/twemoji/svg/1f1ff-1f1e6.svg"
        selected: false
        isToken: false
    }
}
