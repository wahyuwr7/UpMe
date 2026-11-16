// Built-in knowledge the brain starts with. Everything here is overridden by
// what it learns from your confirmations (see `learned_rules` table).

/// Category name -> keywords found in merchant names / notification text.
const categoryKeywords = <String, List<String>>{
  'Food & Drinks': [
    'kopi', 'coffee', 'cafe', 'starbucks', 'kenangan', 'janji jiwa', 'fore', 'mcd', 'mcdonald',
    'kfc', 'burger', 'pizza', 'resto', 'restaurant', 'warung', 'bakso', 'sate', 'gofood',
    'grabfood', 'shopeefood', 'food', 'makan', 'chatime', 'mixue', 'hokben', 'solaria',
    'richeese', 'bakery', 'roti', 'boba', 'tea', 'dining', 'eatery',
  ],
  'Groceries': [
    'indomaret', 'alfamart', 'alfamidi', 'superindo', 'hypermart', 'transmart', 'carrefour',
    'lotte mart', 'ranch market', 'grocery', 'supermarket', 'walmart', 'tesco', 'aldi', 'lidl',
    'whole foods', 'trader joe', 'sayurbox', 'astro', 'segari', 'family mart', 'lawson', '7-eleven',
  ],
  'Transport': [
    'grab', 'gojek', 'goride', 'gocar', 'uber', 'lyft', 'maxim', 'bluebird', 'taxi', 'krl',
    'mrt', 'lrt', 'transjakarta', 'kai', 'commuter', 'parkir', 'parking', 'tol', 'toll', 'e-toll',
    'flazz', 'pertamina', 'shell', 'bp ', 'spbu', 'bensin', 'fuel', 'gas station',
  ],
  'Shopping': [
    'tokopedia', 'shopee', 'lazada', 'blibli', 'bukalapak', 'tiktok shop', 'amazon', 'zalora',
    'uniqlo', 'h&m', 'zara', 'ikea', 'ace hardware', 'informa', 'miniso', 'ebay', 'aliexpress',
    'mall', 'store', 'shop',
  ],
  'Bills & Utilities': [
    'pln', 'listrik', 'electric', 'pdam', 'water', 'telkom', 'indihome', 'biznet', 'first media',
    'myrepublic', 'internet', 'wifi', 'pulsa', 'paket data', 'telkomsel', 'xl', 'indosat', 'tri ',
    'smartfren', 'bpjs', 'tagihan', 'bill', 'insurance', 'asuransi', 'pajak', 'tax',
  ],
  'Entertainment': [
    'netflix', 'spotify', 'youtube', 'disney', 'vidio', 'apple.com', 'itunes', 'google play',
    'steam', 'playstation', 'xbox', 'nintendo', 'cgv', 'xxi', 'cinema', 'cinepolis', 'bioskop',
    'game', 'prime video', 'hbo',
  ],
  'Health': [
    'apotek', 'pharmacy', 'kimia farma', 'guardian', 'watsons', 'century', 'klinik', 'clinic',
    'hospital', 'rumah sakit', 'rs ', 'dokter', 'doctor', 'halodoc', 'alodokter', 'lab',
  ],
  'Travel': [
    'traveloka', 'tiket.com', 'agoda', 'booking.com', 'airbnb', 'hotel', 'garuda', 'lion air',
    'citilink', 'airasia', 'batik air', 'pegipegi', 'expedia', 'airline', 'flight',
  ],
  'Education': ['udemy', 'coursera', 'ruangguru', 'zenius', 'school', 'sekolah', 'kursus', 'course', 'buku', 'gramedia', 'book'],
  'Salary': ['gaji', 'salary', 'payroll', 'thr', 'bonus', 'upah', 'wage'],
  'Refund & Cashback': ['refund', 'cashback', 'pengembalian dana', 'reversal'],
  'Interest': ['bunga', 'interest', 'dividen', 'dividend'],
};

/// Known finance app packages -> friendly hint words (used to match accounts).
const knownFinanceApps = <String, List<String>>{
  'com.bca': ['bca'],
  'com.bca.mybca.omni.android': ['bca', 'mybca'],
  'id.bmri.livin': ['mandiri', 'livin'],
  'id.co.bri.brimo': ['bri', 'brimo'],
  'src.com.bni': ['bni'],
  'com.btpn.dc': ['jenius'],
  'com.bcadigital.blu': ['blu'],
  'com.jago.digitalBanking': ['jago'],
  'id.co.bankbkemobile.digitalbank': ['seabank'],
  'id.co.cimbniaga.mobile.android': ['cimb', 'octo'],
  'com.gojek.app': ['gopay', 'gojek'],
  'com.gojek.gopay': ['gopay'],
  'ovo.id': ['ovo'],
  'id.dana': ['dana'],
  'com.shopee.id': ['shopeepay', 'spaylater'],
  'com.linkaja': ['linkaja'],
  'com.paypal.android.p2pmobile': ['paypal'],
  'com.transferwise.android': ['wise'],
  'com.revolut.revolut': ['revolut'],
  'com.squareup.cash': ['cash app'],
  'com.venmo': ['venmo'],
  'com.google.android.apps.walletnfcrel': ['google wallet', 'google pay'],
};
