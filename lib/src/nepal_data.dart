// lib/src/nepal_data.dart
//
// The validated dataset of Nepal's administrative divisions.
// Counts verified against the official federal structure:
// 7 provinces, 77 districts, 753 local bodies (6/11/276/460), 6,743 wards.
//
// Tracked as Linear issue HYA-312: move this to a canonical data/*.json
// file and generate both this Dart constant and the React explorer's
// dataset from a single source of truth.

/// The package's embedded dataset. Do not construct by hand —
/// use [NepalAdminApi] to query it.
class NepalData {
  static final List<Province> provinces = [
    Province(
      id: 'koshi',
      name: 'Koshi',
      stats: const ProvinceStats(districts: 14, metro: 1, subMetro: 2, mun: 46, ruralMun: 88, total: 137, wards: 1157),
      districts: [
        District(name: 'Bhojpur', rawUnits: 'Bhojpur (M) · Shadananda (M) · Aamchowk (RM) · Arun (RM) · Hatuwagadhi (RM) · Pauwa Dunma (RM) · Ramprasad Rai (RM) · Salpa Silichho (RM) · Tyamke Maiyum (RM)'),
        District(name: 'Dhankuta', rawUnits: 'Dhankuta (M) · Mahalaxmi (M) · Pakhribas (M) · Chaubise (RM) · Chhathar Jorpati (RM) · Sahidbhumi (RM) · Sangurigadhi (RM)'),
        District(name: 'Ilam', rawUnits: 'Deumai (M) · Ilam (M) · Mai (M) · Suryodaya (M) · Chulachuli (RM) · Fakfokathum (RM) · Mai Jogmai (RM) · Mangsebung (RM) · Rong (RM) · Sandakpur (RM)'),
        District(name: 'Jhapa', rawUnits: 'Arjundhara (M) · Bhadrapur (M) · Birtamod (M) · Damak (M) · Gauradaha (M) · Kankai (M) · Mechinagar (M) · Shivasatakshi (M) · Barhadashi (RM) · Buddhashanti (RM) · Gauriganj (RM) · Haldibari (RM) · Jhapa (RM) · Kachanakawal (RM) · Kamal (RM)'),
        District(name: 'Khotang', rawUnits: 'Diktel Rupakot Majhuwagadhi (M) · Halesi Tuwachung (M) · Aiselukharka (RM) · Baraha Pokhari (RM) · Diprung (RM) · Jante Dhunga (RM) · Kepilasgadhi (RM) · Khotehang (RM) · Rawabesi (RM) · Sakela (RM)'),
        District(name: 'Morang', rawUnits: 'Biratnagar (Metro) · Belbari (M) · Letang (M) · Pathari Shanishchare (M) · Rangeli (M) · Ratuwamai (M) · Sundarharaicha (M) · Sunwarshi (M) · Urlabari (M) · Budhiganga (RM) · Dhanapalthan (RM) · Gramthan (RM) · Jahada (RM) · Kanepokhari (RM) · Katahari (RM) · Kerabari (RM) · Miklajung (RM)'),
        District(name: 'Okhaldhunga', rawUnits: 'Siddhicharan (M) · Champadevi (RM) · Chishankhu Gadhi (RM) · Khiji Demba (RM) · Likhu (RM) · Manebhanjyang (RM) · Molung (RM) · Sunkoshi (RM)'),
        District(name: 'Panchthar', rawUnits: 'Phidim (M) · Falelung (RM) · Falgunanda (RM) · Hilihan (RM) · Kummayak (RM) · Miklajung (RM) · Tumbewa (RM) · Yangbarak (RM)'),
        District(name: 'Sankhuwasabha', rawUnits: 'Chainapur (M) · Dharmadevi (M) · Khandabari (M) · Madi (M) · Panchakhapan (M) · Bhotkhola (RM) · Chichila (RM) · Makalu (RM) · Sabhapokhari (RM) · Silichong (RM)'),
        District(name: 'Solukhumbu', rawUnits: 'Solu Dudhkunda (M) · Khumbu Pasanglhamu (RM) · Likhu Pike (RM) · Mahakulung (RM) · Mapya Dudhkoshi (RM) · Necha Salyan (RM) · Sotang (RM) · Thulung Dudhkoshi (RM)'),
        District(name: 'Sunsari', rawUnits: 'Dharan (Sub-Metro) · Itahari (Sub-Metro) · Baraha (M) · Duhabi (M) · Inaruwa (M) · Ramdhuni (M) · Barju (RM) · Bhokraha (RM) · Dewangunj (RM) · Gadhi (RM) · Harinagara (RM) · Koshi (RM)'),
        District(name: 'Taplejung', rawUnits: 'Phungling (M) · Aatharai Tribeni (RM) · Maiwakhola (RM) · Meringden (RM) · Mikwakhola (RM) · Phaktanglung (RM) · Sidingba (RM) · Sirijangha (RM) · Yangwarak (RM)'),
        District(name: 'Terhathum', rawUnits: 'Laligurans (M) · Myanglung (M) · Aatharai (RM) · Chhathar (RM) · Menchhyayem (RM) · Phedap (RM)'),
        District(name: 'Udayapur', rawUnits: 'Belaka (M) · Chaudandigadhi (M) · Katari (M) · Triyuga (M) · Rautamai (RM) · Sunkoshi (RM) · Tapli (RM) · Udayapurgadhi (RM)')
      ]
    ),
    Province(
      id: 'madhesh',
      name: 'Madhesh',
      stats: const ProvinceStats(districts: 8, metro: 1, subMetro: 3, mun: 73, ruralMun: 59, total: 136, wards: 1271),
      districts: [
        District(name: 'Bara', rawUnits: 'Jitpur Simara (Sub-Metro) · Kalaiya (Sub-Metro) · Kolhabi (M) · Mahagadhimai (M) · Nijagadh (M) · Pacharauta (M) · Simroungadh (M) · Aadarsha Kotwal (RM) · Baragadhi (RM) · Bishrampur (RM) · Devtal (RM) · Karaiyamai (RM) · Parawanipur (RM) · Pheta (RM) · Prasauni (RM) · Subarna (RM)'),
        District(name: 'Dhanusha', rawUnits: 'Janakpurdham (Sub-Metro) · Bideha (M) · Chhireshwornath (M) · Dhanushadham (M) · Ganeshman Charnath (M) · Hansapur (M) · Kamala (M) · Mithila (M) · Mithila Bihari (M) · Nagarain (M) · Sabaila (M) · Shahidnagar (M) · Aurahi (RM) · Bateshwor (RM) · Dhanauji (RM) · Janak Nandini (RM) · Laxminiya (RM) · Mukhiyapatti Musaharmiya (RM)'),
        District(name: 'Mahottari', rawUnits: 'Aurahi (M) · Balawa (M) · Bardibas (M) · Bhangaha (M) · Gaushala (M) · Jaleshwor (M) · Loharpatti (M) · Manara Shisawa (M) · Matihani (M) · Ram Gopalpur (M) · Ekadara (RM) · Mahottari (RM) · Pipara (RM) · Samsi (RM) · Sonama (RM)'),
        District(name: 'Parsa', rawUnits: 'Birgunj (Metro) · Bahudarmai (M) · Parsagadhi (M) · Pokhariya (M) · Bindabasini (RM) · Chhipaharmai (RM) · Dhobini (RM) · Jagarnathpur (RM) · Jirabhawani (RM) · Kalikamai (RM) · Pakaha Mainpur (RM) · Paterwa Sugauli (RM) · Sakhuwa Prasauni (RM) · Thori (RM)'),
        District(name: 'Rautahat', rawUnits: 'Boudhimai (M) · Brindaban (M) · Chandrapur (M) · Dewahi Gonahi (M) · Gadhimai (M) · Garuda (M) · Gaur (M) · Gujara (M) · Ishanath (M) · Katahariya (M) · Madhav Narayan (M) · Maulapur (M) · Paroha (M) · Phatuwa Bijayapur (M) · Rajdevi (M) · Rajpur (M) · Durga Bhagawati (RM) · Yamunamai (RM)'),
        District(name: 'Saptari', rawUnits: 'BodeBarsain (M) · Dakneshwori (M) · Hanumannagar Kankalini (M) · Kanchanrup (M) · Khadak (M) · Rajbiraj (M) · Saptakoshi (M) · Shambhunath (M) · Surunga (M) · Agnisair Krishna Sabaran (RM) · Balan-Bihul (RM) · Belhi Chapena (RM) · Bishnupur (RM) · Chhinnamasta (RM) · Mahadewa (RM) · Rupani (RM) · Tilathi Koiladi (RM) · Tirahut (RM)'),
        District(name: 'Sarlahi', rawUnits: 'Bagmati (M) · Balara (M) · Barahathawa (M) · Godaita (M) · Haripur (M) · Haripurwa (M) · Hariwan (M) · Ishworpur (M) · Kabilashi (M) · Lalbandi (M) · Malangawa (M) · Basbariya (RM) · Bishnu (RM) · Brahmapuri (RM) · Chakraghatta (RM) · Chandranagar (RM) · Dhanakaul (RM) · Kaudena (RM) · Parsa (RM) · Ramnagar (RM)'),
        District(name: 'Siraha', rawUnits: 'Dhangadhimai (M) · Golbazar (M) · Kalyanpur (M) · Karjanha (M) · Lahan (M) · Mirchaiya (M) · Siraha (M) · Sukhipur (M) · Arnama (RM) · Aurahi (RM) · Bariyarpatti (RM) · Bhagawanpur (RM) · Bishnupur (RM) · Laxmipur Patari (RM) · Naraha (RM) · Nawarajpur (RM) · Sakhuwa Nankarkatti (RM)')
      ]
    ),

    Province(
      id: 'bagmati',
      name: 'Bagmati',
      stats: const ProvinceStats(districts: 13, metro: 3, subMetro: 1, mun: 41, ruralMun: 74, total: 119, wards: 1121),
      districts: [
        District(name: 'Bhaktapur', rawUnits: 'Bhaktapur (M) · Changunarayan (M) · Madhyapur Thimi (M) · Suryabinayak (M)'),
        District(name: 'Chitwan', rawUnits: 'Bharatpur (Metro) · Kalika (M) · Khairhani (M) · Madi (M) · Rapti (M) · Ratnanagar (M) · Ichchhakamana (RM)'),
        District(name: 'Dhading', rawUnits: 'Dhunibenshi (M) · Nilkhantha (M) · Benighat Rorang (RM) · Gajuri (RM) · Galchhi (RM) · Ganga Jamuna (RM) · Jwalamukhi (RM) · Khaniyabas (RM) · Netrawati (RM) · Rubi Valley (RM) · Siddhalek (RM) · Thakre (RM) · Tripurasundari (RM)'),
        District(name: 'Dolakha', rawUnits: 'Bhimeshwor (M) · Jiri (M) · Baitedhar (RM) · Bigu (RM) · Gaurishankar (RM) · Kalinchowk (RM) · Melung (RM) · Shailung (RM) · Tamakoshi (RM)'),
        District(name: 'Kathmandu', rawUnits: 'Kathmandu (Metro) · Budhanilkantha (M) · Chandragiri (M) · Dakshinkali (M) · Gokarneshwar (M) · Kageshwari Manohara (M) · Kirtipur (M) · Nagarjun (M) · Shankharapur (M) · Tarakeshwar (M) · Tokha (M)'),
        District(name: 'Kavrepalanchok', rawUnits: 'Banepa (M) · Dhulikhel (M) · Mandan Deupur (M) · Namobuddha (M) · Panauti (M) · Panchkhal (M) · Bethanchowk (RM) · Bhumlu (RM) · Chauri Deurali (RM) · Khanikhola (RM) · Mahabharat (RM) · Roshi (RM) · Temal (RM)'),
        District(name: 'Lalitpur', rawUnits: 'Lalitpur (Metro) · Godawari (M) · Mahalaxmi (M) · Bagmati (RM) · Konjyosom (RM) · Mahankal (RM)'),
        District(name: 'Makwanpur', rawUnits: 'Hetauda (Sub-Metro) · Thaha (M) · Bagmati (RM) · Bakaiya (RM) · Bhimphedi (RM) · Indrasarowar (RM) · Kailash (RM) · Makawanpurgadhi (RM) · Manahari (RM) · Raksirang (RM)'),
        District(name: 'Nuwakot', rawUnits: 'Belkotgadhi (M) · Bidur (M) · Dupcheshwor (RM) · Kakani (RM) · Kispang (RM) · Likhu (RM) · Meghang (RM) · Panchakanya (RM) · Shivapuri (RM) · Suryagadhi (RM) · Tadi (RM) · Tarakeshwar (RM)'),
        District(name: 'Ramechhap', rawUnits: 'Manthali (M) · Ramechhap (M) · Doramba (RM) · Gokulganga (RM) · Khandadevi (RM) · Likhu (RM) · Sunapati (RM) · Umakunda (RM)'),
        District(name: 'Rasuwa', rawUnits: 'Aamachhodingmo (RM) · Gosaikunda (RM) · Kalika (RM) · Naukunda (RM) · Uttargaya (RM)'),
        District(name: 'Sindhuli', rawUnits: 'Dudhouli (M) · Kamalamai (M) · Ghyanglekha (RM) · Golanjor (RM) · Hariharpurgaghi (RM) · Marin (RM) · Phikkal (RM) · Sunkoshi (RM) · Tinpatan (RM)'),
        District(name: 'Sindhupalchok', rawUnits: 'Bahrabise (M) · Chautara Sangachowkgadhi (M) · Melamchi (M) · Balephi (RM) · Bhotekoshi (RM) · Helambu (RM) · Indrawoti (RM) · Jugal (RM) · Lisankhu Pakhar (RM) · Panchpokhari Thangpal (RM) · Sunkoshi (RM) · Tripurasundari (RM)')
      ]
    ),
    Province(
      id: 'gandaki',
      name: 'Gandaki',
      stats: const ProvinceStats(districts: 11, metro: 1, subMetro: 0, mun: 26, ruralMun: 58, total: 85, wards: 759),
      districts: [
        District(name: 'Baglung', rawUnits: 'Baglung (M) · Dhorpatan (M) · Galkot (M) · Jaimini (M) · Badigad (RM) · Bareng (RM) · Kathekhola (RM) · Nisikhola (RM) · Tamankhola (RM) · Tarakhola (RM)'),
        District(name: 'Gorkha', rawUnits: 'Gorkha (M) · Palungtar (M) · Aarughat (RM) · Ajirkot (RM) · Bhimsen (RM) · Chumanubri (RM) · Dharche (RM) · Gandaki (RM) · Shahid Lakhan (RM) · Siranchowk (RM) · Sulikot (RM)'),
        District(name: 'Kaski', rawUnits: 'Pokhara (Metro) · Annapurna (RM) · Machhapuchchhre (RM) · Madi (RM) · Rupa (RM)'),
        District(name: 'Lamjung', rawUnits: 'Bensi Shahar (M) · Madhya Nepal (M) · Rainas (M) · Sundarbazar (M) · Dordi (RM) · Dudhapokhari (RM) · Kwhola Sothar (RM) · Marshyangdi (RM)'),
        District(name: 'Manang', rawUnits: 'Chame (RM) · Naraphu (RM) · Nashong (RM) · Neshang (RM)'),
        District(name: 'Mustang', rawUnits: 'Barhagaun Muktichhetra (RM) · Dalome (RM) · Gharapjhong (RM) · Lomanthang (RM) · Thasang (RM)'),
        District(name: 'Myagdi', rawUnits: 'Beni (M) · Annapurna (RM) · Dhawalagiri (RM) · Malika (RM) · Mangala (RM) · Raghuganga (RM)'),
        District(name: 'Nawalpur', rawUnits: 'Devchuli (M) · Gaidakot (M) · Kawasoti (M) · Madhya Bindu (M) · Binayi Tribeni (RM) · Bulingtar (RM) · Bungdikali (RM) · Hupsekot (RM)'),
        District(name: 'Parbat', rawUnits: 'Kushma (M) · Phalebas (M) · Bihadi (RM) · Jaljala (RM) · Mahashila (RM) · Modi (RM) · Paiyu (RM)'),
        District(name: 'Syangja', rawUnits: 'Bhirkot (M) · Chapakot (M) · Galyang (M) · Putalibazar (M) · Walling (M) · Aandhikhola (RM) · Arjunchaupari (RM) · Biruwa (RM) · Harinas (RM) · Kaligandaki (RM) · Phedikhola (RM)'),
        District(name: 'Tanahun', rawUnits: 'Bhanu (M) · Bhimad (M) · Byas (M) · Shuklagandaki (M) · Aanbu Khaireni (RM) · Bandipur (RM) · Devghat (RM) · Ghiring (RM) · Myagde (RM) · Rishing (RM)')
      ]
    ),

    Province(
      id: 'lumbini',
      name: 'Lumbini',
      stats: const ProvinceStats(districts: 12, metro: 0, subMetro: 4, mun: 32, ruralMun: 73, total: 109, wards: 983),
      districts: [
        District(name: 'Arghakhanchi', rawUnits: 'Bhumikasthan (M) · Sandhikharka (M) · Shitaganga (M) · Chhatradev (RM) · Malarani (RM) · Panini (RM)'),
        District(name: 'Banke', rawUnits: 'Nepalgunj (Sub-Metro) · Kohalpur (M) · Baijanath (RM) · Duduwa (RM) · Janaki (RM) · Khajura (RM) · Narainapur (RM) · Rapti Sonari (RM)'),
        District(name: 'Bardiya', rawUnits: 'Bansgadhi (M) · Barbardiya (M) · Gulariya (M) · Madhuwan (M) · Rajapur (M) · Thakurbaba (M) · Badhaiyatal (RM) · Geruwa (RM)'),
        District(name: 'Dang', rawUnits: 'Ghorahi (Sub-Metro) · Tulsipur (Sub-Metro) · Lamahi (M) · Babai (RM) · Bangalachuli (RM) · Dangisharan (RM) · Gadhawa (RM) · Rajpur (RM) · Rapti (RM) · Shantinagar (RM)'),
        District(name: 'Gulmi', rawUnits: 'Musikot (M) · Resunga (M) · Chandrakot (RM) · Chhatrakot (RM) · Dhurkot (RM) · Gulmi Durbar (RM) · Isma (RM) · Kali Gandaki (RM) · Madane (RM) · Malika (RM) · Ruru (RM) · Satyawoti (RM)'),
        District(name: 'Kapilvastu', rawUnits: 'Banganga (M) · Buddhabhumi (M) · Kapilvastu (M) · Krishnanagar (M) · Maharajganj (M) · Shivaraj (M) · Bijayanagar (RM) · Mayadevi (RM) · Shuddhodhan (RM) · Yasodhara (RM)'),
        District(name: 'Palpa', rawUnits: 'Rampur (M) · Tansen (M) · Baganaskali (RM) · Mathagadhi (RM) · Nisdi (RM) · Purbakhola (RM) · Rainadevi Chhahara (RM) · Rambha (RM) · Ribdikot (RM) · Tinau (RM)'),
        District(name: 'Parasi (Nawalparasi West)', rawUnits: 'Bardaghat (M) · Ramgram (M) · Sunawal (M) · Palhinandan (RM) · Pratapapur (RM) · Sarawal (RM) · Susta (RM)'),
        District(name: 'Pyuthan', rawUnits: 'Pyuthan (M) · Sworgadwari (M) · Airawati (RM) · Gaumukhi (RM) · Jhimaruk (RM) · Mallarani (RM) · Mandavi (RM) · Naubahini (RM) · Sarumarani (RM)'),
        District(name: 'Rolpa', rawUnits: 'Rolpa (M) · Gangadev (RM) · Lungri (RM) · Madi (RM) · Paribartan (RM) · Runtigadhi (RM) · Sunchhahari (RM) · Sunil Smriti (RM) · Thabang (RM) · Tribeni (RM)'),
        District(name: 'Rukum East', rawUnits: 'Bhoome (RM) · Putha Uttanganga (RM) · Sisne (RM)'),
        District(name: 'Rupandehi', rawUnits: 'Butwal (Sub-Metro) · Devdaha (M) · Lumbini Sanskritik (M) · Sainamaina (M) · Siddharthanagar (M) · Tilottama (M) · Gaidahawa (RM) · Kanchan (RM) · Kotahimai (RM) · Marchawari (RM) · Mayadevi (RM) · Om Satiya (RM) · Rohini (RM) · Sammarimai (RM) · Siyari (RM) · Suddhodhan (RM)')
      ]
    ),
    Province(
      id: 'karnali',
      name: 'Karnali',
      stats: const ProvinceStats(districts: 10, metro: 0, subMetro: 0, mun: 25, ruralMun: 54, total: 79, wards: 718),
      districts: [
        District(name: 'Dailekh', rawUnits: 'Aathbis (M) · Chamunda Bindrasaini (M) · Dullu (M) · Narayan (M) · Bhagawatimai (RM) · Bhairabi (RM) · Dungeshwor (RM) · Gurans (RM) · Mahabu (RM) · Naumule (RM) · Thantikandh (RM)'),
        District(name: 'Dolpa', rawUnits: 'Thulibheri (M) · Tripurasundari (M) · Chharka Tangsong (RM) · Dolpo Buddha (RM) · Jagadulla (RM) · Kaike (RM) · Mudkechula (RM) · Shey Phoksundo (RM)'),
        District(name: 'Humla', rawUnits: 'Adanchuli (RM) · Chankheli (RM) · Kharpunath (RM) · Namkha (RM) · Sarkegad (RM) · Simkot (RM) · Tanjakot (RM)'),
        District(name: 'Jajarkot', rawUnits: 'Bheri (M) · Chhedagad (M) · Nalagad (M) · Barekot (RM) · Junichande (RM) · Kuse (RM) · Shivalaya (RM)'),
        District(name: 'Jumla', rawUnits: 'Chandannath (M) · Guthichaur (RM) · Hima (RM) · Kanaka Sundari (RM) · Patarasi (RM) · Sinja (RM) · Tatopani (RM) · Tila (RM)'),
        District(name: 'Kalikot', rawUnits: 'Khandachakra (M) · Raskot (M) · Tilagupha (M) · Kalika (RM) · Mahawai (RM) · Naraharinath (RM) · Pachal Jharana (RM) · Palata (RM) · Sanni Tribeni (RM)'),
        District(name: 'Mugu', rawUnits: 'Chhayanath Rara (M) · Khatyad (RM) · Mugu Karmarong (RM) · Soru (RM)'),
        District(name: 'Rukum West', rawUnits: 'Aathabisakot (M) · Chaurjahari (M) · Musikot (M) · Banphikot (RM) · Sanibheri (RM) · Tribeni (RM)'),
        District(name: 'Salyan', rawUnits: 'Bagachour (M) · Banagad Kupinde (M) · Sharada (M) · Chhatreshwori (RM) · Darma (RM) · Dhorchaur (RM) · Kalimati (RM) · Kapurkot (RM) · Kumakh Malika (RM) · Tribeni (RM)'),
        District(name: 'Surkhet', rawUnits: 'Bheriganga (M) · Birendranagar (M) · Gurbhakot (M) · Lekabeshi (M) · Panchapuri (M) · Barahatal (RM) · Chaukune (RM) · Chingad (RM) · Simta (RM)')
      ]
    ),
    Province(
      id: 'sudurpashchim',
      name: 'Sudurpashchim',
      stats: const ProvinceStats(districts: 9, metro: 0, subMetro: 1, mun: 33, ruralMun: 54, total: 88, wards: 734),
      districts: [
        District(name: 'Achham', rawUnits: 'Kamal Bazar (M) · Mangalsen (M) · Panchdebal Binayak (M) · Sanphebagar (M) · Bannigadhi Jayagadh (RM) · Chaurpati (RM) · Dhakari (RM) · Mellekh (RM) · Ramaroshan (RM) · Turmakhand (RM)'),
        District(name: 'Baitadi', rawUnits: 'Dasharathchand (M) · Melauli (M) · Patan (M) · Puchaundi (M) · Dilasaini (RM) · Dogada Kedar (RM) · Pancheshwor (RM) · Shivanath (RM) · Sigas (RM) · Surnaya (RM)'),
        District(name: 'Bajhang', rawUnits: 'Bungal (M) · Jayaprithvi (M) · Bitthadchir (RM) · Chhabis Pathibhara (RM) · Durgathali (RM) · Kanda (RM) · Kedarsyun (RM) · Khaptad Chhanna (RM) · Masta (RM) · Surma (RM) · Talkot (RM) · Thalara (RM)'),
        District(name: 'Bajura', rawUnits: 'Badimalika (M) · Budhiganga (M) · Budhinanda (M) · Tribeni (M) · Gaumul (RM) · Himali (RM) · Jagannath (RM) · Khaptad Chhededaha (RM) · Swami Kartik (RM)'),
        District(name: 'Dadeldhura', rawUnits: 'Amargadhi (M) · Parashuram (M) · Aalital (RM) · Ajayameru (RM) · Bhageshwor (RM) · Ganyapdhura (RM) · Nawadurga (RM)'),
        District(name: 'Darchula', rawUnits: 'Mahakali (M) · Shailyashikhar (M) · Apihimal (RM) · Byas (RM) · Duhun (RM) · Lekam (RM) · Malikarjun (RM) · Marma (RM) · Naugad (RM)'),
        District(name: 'Doti', rawUnits: 'Dipayal Silgadhi (M) · Shikhar (M) · Aadarsha (RM) · Badi Kedar (RM) · Bogatan (RM) · Jorayal (RM) · K.I. Singh (RM) · Purbichouki (RM) · Sayal (RM)'),
        District(name: 'Kailali', rawUnits: 'Dhangadhi (Sub-Metro) · Bhajani (M) · Gauriganga (M) · Ghodaghodi (M) · Godawari (M) · Lamki Chuha (M) · Tikapur (M) · Bardagoriya (RM) · Chure (RM) · Janaki (RM) · Joshipur (RM) · Kailari (RM) · Mohanyal (RM)'),
        District(name: 'Kanchanpur', rawUnits: 'Bedkot (M) · Belouri (M) · Bhimdatta (M) · Krishnapur (M) · Mahakali (M) · Punarbas (M) · Shuklaphanta (M) · Beldandi (RM) · Laljhadi (RM)')
      ]
    ),
  ];
}
