// Major cities per Indian state / UT. Not exhaustive — the picker adds an
// "Other…" option that lets the user type a city/town not listed here.
const Map<String, List<String>> kIndiaStateCities = {
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Guntur',
    'Nellore',
    'Kurnool',
    'Tirupati',
    'Rajahmundry',
    'Kakinada'
  ],
  'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Pasighat', 'Tawang'],
  'Assam': [
    'Guwahati',
    'Silchar',
    'Dibrugarh',
    'Jorhat',
    'Nagaon',
    'Tinsukia',
    'Tezpur'
  ],
  'Bihar': [
    'Patna',
    'Gaya',
    'Bhagalpur',
    'Muzaffarpur',
    'Darbhanga',
    'Purnia',
    'Bihar Sharif',
    'Arrah'
  ],
  'Chhattisgarh': [
    'Raipur',
    'Bhilai',
    'Bilaspur',
    'Korba',
    'Durg',
    'Raigarh',
    'Jagdalpur'
  ],
  'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda'],
  'Gujarat': [
    'Ahmedabad',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bhavnagar',
    'Jamnagar',
    'Gandhinagar',
    'Junagadh',
    'Anand'
  ],
  'Haryana': [
    'Faridabad',
    'Gurugram',
    'Panipat',
    'Ambala',
    'Yamunanagar',
    'Rohtak',
    'Hisar',
    'Karnal',
    'Sonipat',
    'Panchkula'
  ],
  'Himachal Pradesh': [
    'Shimla',
    'Mandi',
    'Solan',
    'Dharamshala',
    'Kullu',
    'Una',
    'Hamirpur'
  ],
  'Jharkhand': [
    'Ranchi',
    'Jamshedpur',
    'Dhanbad',
    'Bokaro',
    'Deoghar',
    'Hazaribagh'
  ],
  'Karnataka': [
    'Bengaluru',
    'Mysuru',
    'Hubli-Dharwad',
    'Mangaluru',
    'Belagavi',
    'Kalaburagi',
    'Davanagere',
    'Ballari',
    'Tumakuru',
    'Shivamogga'
  ],
  'Kerala': [
    'Thiruvananthapuram',
    'Kochi',
    'Kozhikode',
    'Thrissur',
    'Kollam',
    'Kannur',
    'Alappuzha',
    'Palakkad'
  ],
  'Madhya Pradesh': [
    'Indore',
    'Bhopal',
    'Jabalpur',
    'Gwalior',
    'Ujjain',
    'Sagar',
    'Satna',
    'Ratlam',
    'Rewa'
  ],
  'Maharashtra': [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Aurangabad',
    'Solapur',
    'Kolhapur',
    'Amravati',
    'Navi Mumbai',
    'Sangli'
  ],
  'Manipur': ['Imphal', 'Thoubal', 'Bishnupur', 'Churachandpur'],
  'Meghalaya': ['Shillong', 'Tura', 'Jowai', 'Nongstoin'],
  'Mizoram': ['Aizawl', 'Lunglei', 'Champhai', 'Serchhip'],
  'Nagaland': ['Kohima', 'Dimapur', 'Mokokchung', 'Tuensang'],
  'Odisha': [
    'Bhubaneswar',
    'Cuttack',
    'Rourkela',
    'Berhampur',
    'Sambalpur',
    'Puri',
    'Balasore'
  ],
  'Punjab': [
    'Ludhiana',
    'Amritsar',
    'Jalandhar',
    'Patiala',
    'Bathinda',
    'Mohali',
    'Hoshiarpur',
    'Pathankot',
    'Moga',
    'Firozpur',
    'Khanna',
    'Phagwara'
  ],
  'Rajasthan': [
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Kota',
    'Bikaner',
    'Ajmer',
    'Bhilwara',
    'Alwar',
    'Sikar'
  ],
  'Sikkim': ['Gangtok', 'Namchi', 'Gyalshing', 'Mangan'],
  'Tamil Nadu': [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Tiruchirappalli',
    'Salem',
    'Tirunelveli',
    'Erode',
    'Vellore',
    'Thoothukudi',
    'Tiruppur'
  ],
  'Telangana': [
    'Hyderabad',
    'Warangal',
    'Nizamabad',
    'Karimnagar',
    'Khammam',
    'Ramagundam'
  ],
  'Tripura': ['Agartala', 'Udaipur', 'Dharmanagar', 'Kailashahar'],
  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Ghaziabad',
    'Agra',
    'Varanasi',
    'Meerut',
    'Prayagraj',
    'Noida',
    'Bareilly',
    'Aligarh',
    'Moradabad',
    'Gorakhpur'
  ],
  'Uttarakhand': [
    'Dehradun',
    'Haridwar',
    'Roorkee',
    'Haldwani',
    'Rudrapur',
    'Rishikesh',
    'Nainital'
  ],
  'West Bengal': [
    'Kolkata',
    'Howrah',
    'Asansol',
    'Siliguri',
    'Durgapur',
    'Bardhaman',
    'Malda',
    'Kharagpur'
  ],
  // Union Territories
  'Andaman and Nicobar Islands': ['Port Blair'],
  'Chandigarh': ['Chandigarh'],
  'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Silvassa', 'Diu'],
  'Delhi': ['New Delhi', 'Delhi', 'Dwarka', 'Rohini', 'Saket', 'Pitampura'],
  'Jammu and Kashmir': [
    'Srinagar',
    'Jammu',
    'Anantnag',
    'Baramulla',
    'Udhampur'
  ],
  'Ladakh': ['Leh', 'Kargil'],
  'Lakshadweep': ['Kavaratti'],
  'Puducherry': ['Puducherry', 'Karaikal', 'Yanam', 'Mahe'],
};

List<String> get kIndiaStates => kIndiaStateCities.keys.toList();

List<String> citiesForState(String state) =>
    kIndiaStateCities[state] ?? const [];
