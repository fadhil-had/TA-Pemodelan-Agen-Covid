/**
* Name: tugasAkhir
* Based on the internal empty template. 
* Author: Azka
* Tags: 
*/


model tugasAkhirAzka

import "agen_Azka.gaml"

/* Insert your model definition here */

global{
	//Input Parameter
	int num_population; //Initial population
	int num_family; //Initial family, input from user
	//int num_building; //Initial building
	int num_init_infected; //Initial confirmed status, input from user
	int patient_cap;
	int icu_cap;
	int ven_cap;
	float obedience;
	float test_accuracy;
	float hospital_threshold;
	
	//float test_accuracy;
	float contact_tracing_effectiveness; //Input from user
	float sensitivity_pcr; //Input
	float specificity_pcr; //Input
	float sensitivity_rapid; //Input
	float specificity_rapid; //Input
	float quarantine_obedience <- 0.73; //Initial obedience from data in journal
	float mask_obedience <- 0.81; //Initial obedience from data in journal
	float mask_effectiveness <- 0.77; //sumber?
	int simulation_days; //Jumlah hari simulasi
	
	//Demographical Parameters
	int min_age <- 1;
	int min_student_age <- 4;
	int max_student_age <- 24;
	int min_working_age <- 15;
	int max_working_age <- 60;
	int max_age <- 100;
	float proba_15_school <- 0.6982; //sumber: BPS Surabaya & BPS Nasional
	float proba_19_school <- 0.1176; 
	
	float proba_active_family <- 0.9; //Di cek lagi kemungkinannya ??
	float proba_employed_male <- 0.8251; //Jumlah laki2 bekerja, Sumber: BPS Nasional
	float proba_employed_female <- 0.5089; //Jumlah perempuan bekerja
	float proba_works_at_home <- 0.03; //Jumlah WFH
	int max_num_children <- 3; //Belum
	float proba_others <- 0.25; //Proba banyaknya orang lain di dalam satu rumah
	
	//TIME DIVISION
	list<int> morning <- [7,8,9,10];
	list<int> daytime <- [11,12,13,14];
	list<int> evening <- [15,16,17,18];
	list<int> night <- [19,20,21,22];
	list<int> midnight <- [23,0,1,2,3,4,5,6];
	list<list<int>> time_of_day <- [morning, daytime, evening, night, midnight];
	
	
	map<list<int>,list<float>> clinical_fraction <- [ //Belum
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[0.29,0.059],
		[10,19]::[0.205,0.052],
		[20,29]::[0.265,0.052],
		[30,39]::[0.325,0.052],
		[40,49]::[0.4,0.059],
		[50,59]::[0.49,0.059],
		[60,69]::[0.645,0.067],
		[70,90]::[0.695,0.067]
	];
	list<float> serial_distribution <- [2.29,0.36]; // Tipe data berbentuk list, berisi parameter distribusi probabilitas.
	map<list<int>,list<float>> susceptibility <- [ //Kerentanan
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[0.395,0.082],
		[10,19]::[0.375,0.067],
		[20,29]::[0.79,0.104],
		[30,39]::[0.865,0.082],
		[40,49]::[0.8,0.089],
		[50,59]::[0.82,0.089],
		[60,69]::[0.88,0.074],
		[70,90]::[0.74,0.089]
	];

	map<list<int>,int> incubation_distribution <- [ 
	//Distribusi periode inkubasi berdasarkan umur, rata2 4-5 hari bisa dicari lagi
		[0,14]::3,
		[15,29]::5,
		[30,44]::4,
		[45,59]::3,
		[60,74]::2,
		[75,89]::2,
		[89,max_age]::2
	];
	map<list<int>,float> asymptomic_distribution <- [
	//Kemungkinan asimptomp berdasarkan umur
		 
		[0,19]::0.701,
		[20,29]::0.626,
		[30,39]::0.596,
		[40,49]::0.573,
		[50,59]::0.599,
		[60,69]::0.616,
		[70,max_age]::0.687
	];
	map<list<int>,float> moderate_distribution <- [
	//Kemungkinan dirawat, untuk menentukan mild or moderate
		 
		[0,9]::0.26,
		[10,19]::0.07,
		[20,29]::0.14,
		[30,49]::0.2,
		[50,69]::0.37,
		[70,max_age]::0.55
	];
	map<list<int>,float> hospitalization_distribution <- [
	//Kemungkinan dirawat, untuk menentukan mild or moderate
		 
		[0,9]::0.26,
		[10,19]::0.07,
		[20,29]::0.14,
		[30,49]::0.2,
		[50,69]::0.37,
		[70,max_age]::0.55
	];
	map<list<int>,float> ICU_distribution <- [
	//Kemungkinan masuk ICU, untuk menentukan moderate or severe
		[0,9]::0.008,
		[10,19]::0.01,
		[20,29]::0.006,
		[30,49]::0.011,
		[50,69]::0.037,
		[70,max_age]::0.032
	];
	map<list<int>,float> fatality_distribution <- [ //Nemu
	//Kemungkinan fatal, between severe and death
		[0,9]::0,
		[10,19]::0.004,
		[20,29]::0.003,
		[30,49]::0.002,
		[50,69]::0.014,
		[70,max_age]::0.11
	];
	map<list<int>,float> death_distribution <- [ //Nemu
	//Kemungkinan kematian jika keadaan Covid
		[0,9]::0.01,
		[10,19]::0.002,
		[20,29]::0.002,
		[30,49]::0.004,
		[50,59]::0.013,
		[60,69]::0.036,
		[70,79]::0.08,
		[80,max_age]::0.15
	];
	list<float> days_diagnose <- [3.57,0.65]; //Hari menuju terdiagnosa
	
	map<list<int>, list<float>> days_symptom_until_recovered <- [
		/*
		 * Distribusi hari sejak muncul symptoms hingga sembuh
		 */
		 
		[1,9]::[17.65,1.2],
		[10,19]::[19.35,1.81],
		[20,29]::[19.25,0.89],
		[30,39]::[19.25,0.64],
		[40,49]::[21.7,0.87],
		[50,59]::[22.45,0.84],
		[60,69]::[22.95,0.89],
		[70,90]::[24.4,0.97]
	];
	
	
	//BEHAVIORAL PARAMETERS
	float proba_voluntary_random_test <- 0.05; //Kemungkinan test secara volunteer
	float proba_test <- 1.0; //Kemungkinan test
	float proba_activity_morning <-0.15;
	float proba_activity_daytime <-0.25;
	float proba_activity_evening <-0.325;
	float proba_activity_night <-0.05;
	float proba_activity_midnight <- 0.01;
	list<float> proba_activities <- [
		proba_activity_morning,
		proba_activity_daytime,
		proba_activity_evening,
		proba_activity_night,
		proba_activity_midnight
	];
	float activity_reduction_factor <- 0.0;
	float mask_usage_proportion <- 0.85; //Ga sesuai sumber atau sumbernya dari paper di grup
	float infection_reduction_factor <- 0.0;
	float proportion_quarantined_transmission <- 0.1; //Ga sesuai sumber???
	
	
}