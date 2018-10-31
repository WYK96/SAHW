#!/bin/sh

# This is sahw2-2 ---- Course Registration System
# Main idea:
# 1.Download json file of timetable if it doesn't exit;
# 2.Use built-in commands to remove unwanted information;
# 3.Show your course schedule on the terminal;
# 4.Use dialog to do course selection, collision detection;
# 5.Save the state of your course selection.

# files stored in the system
SELECTED_COURSES="./selected_courses.txt" # a file used to store selected courses
COURSE_LIST="./course_list.txt" # a file used to store all courses downloaded from file system
SCHEDULE_TEMPLATE="./schedule.txt" # a file used to store empty course schedule
VALUES="" # store buildlist output
NAME_LOC=0 # 0 represents show course name, 1 represents show course location
TEMP_SCHEDULE="./temp_schedule.txt"

TEMP_SELECTION=""

TEMP_COLLISION="./temp_collision.txt" # store formated possible collision info of selected courses
TEMP_COLLISION_ALL="./temp_collision_all.txt" # store formated possible collision info of all courses
TEMP_CONTAINER="./temp_container.txt"
IS_COLLISION_HAPPENED=0
IS_COLLISION_HAPPENED_ALL=0
COLLISION_STR="" # a string used to store dialog message
COLLISION_STR_ALL=""

IS_SIMPLE_TABLE=0

NANE_TIME_SEARCH=0

# This command is used to get course time and name on timeTable
# For beginners, use curl to get json file of specified web page under the given conditions,
#which will be filled into your course schedule later
# On top of that, use commands like sed,awk,etc. to format the contents of json file
# Finally, save the selected data to the file system
if [ -e course_list.txt ]; then
	echo "course list already downloaded, next step...";
else
	echo "course list doesn't exist, downloading...";
	curl 'https://timetable.nctu.edu.tw/?r=main/get_cos_list' --data 'm_acy=107&m_sem=1&m_degree=3&m_dep_id=17&m_group=**&m_grade=**&m_class=**&m_option=**&m_crsname=**&m_teaname=**&m_cos_id=**&m_cos_code=**&m_crstime=**&m_crsoutline=**&m_costype=**' | \
	       	tr '{' '\n' | tr '}' '\n' | grep 'acy' | sed -e 's/","/"|"/g' | \
	       	awk -F\| '{print $12 "|" $14}' | \
		grep 'cos_time' | \
		sed -e 's/\":\"/\"|\"/g' -e 's/\"//g' | \
		awk -F\| '{print $2 "|" $4}' | \
		awk '{print "\"" $0 "\" off"}'  | \
		nl | \
		sed -e 's/^ *//' > $COURSE_LIST;
	echo "course list generated successfully.";
fi

FILL_SCHEDULE() {
	cp $SCHEDULE_TEMPLATE temp_schedule.txt
#	TEMP_SCHEDULE="./temp_schedule.txt"
	for cos_num in $(cat $SELECTED_COURSES);do
		# Fill in the blank one by one
		cos_info=$( grep -w "^$cos_num" $COURSE_LIST | awk -F\" '{print $2}' ) # cos_info sample: 3IJK4B-EC325|Intro. to Network
		cos_name=$( echo $cos_info | awk -F\| '{print $2}' )	# cos_name sample: Intro. to Network
		cos_time_location=$( echo $cos_info | awk -F\| '{print $1}' )	# cos_time_location sample: 3IJK4B-EC325,5EF-EDB27
		for sub_time_location in $( echo $cos_time_location | tr "," " " );do # format: ${COURSE_TIME}-${CORSE_LOCATION}
			sub_time=$( echo $sub_time_location | awk -F\- '{print $1}' ) # sub_time samle: 3IJK4B
			sub_location=$( echo $sub_time_location | awk -F\- '{print $2}' ) # sub_location sample: EC325
			i=1
			while [ $i -le ${#sub_time} ]; do
				cur_char=$( echo $sub_time | cut -c$i  )
				expr 1 + $cur_char > /dev/null 2>&1
				if [ $? -eq 0 ]; then
					cur_day=$cur_char
				else
					case $cur_char in
						A) cur_hour=1;;
						B) cur_hour=2;;
						C) cur_hour=3;;
						D) cur_hour=4;;
						E) cur_hour=5;;
						F) cur_hour=6;;
						G) cur_hour=7;;
						H) cur_hour=8;;
						I) cur_hour=9;;
						J) cur_hour=10;;
						K) cur_hour=11;;
					esac
					cur_row=$(( 2 + 4*($cur_hour - 1) ))
					# change blank to course name
					if [ $NAME_LOC -eq 0 ]; then
						disp_str="$cos_name"
					else
						disp_str="$sub_location"
					fi
					disp_length=${#disp_str}
					while [ $disp_length -lt 48 ]; do
						disp_str=$disp_str" "
						disp_length=$(( $disp_length + 1 ))
					done
					sub_name1=$(echo "$disp_str" | awk '{print substr($0,1,16)}')
					sub_name2=$(echo "$disp_str" | awk '{print substr($0,17,16)}')
					sub_name3=$(echo "$disp_str" | awk '{print substr($0,33,16)}')
					sub_str=$(cat $TEMP_SCHEDULE | sed -n ${cur_row}p | \
						awk -F\| 'BEGIN{OFS="\|"} { $cur_column=disp_str; print $0 }' \
						cur_column=$(( $cur_day + 1 )) disp_str="$sub_name1")
					sed -i '' "${cur_row}s/^.*$/$sub_str/" $TEMP_SCHEDULE
					cur_row=$(( $cur_row + 1 ))
					sub_str=$(cat $TEMP_SCHEDULE | sed -n ${cur_row}p | \
						awk -F\| 'BEGIN{OFS="\|"} { $cur_column=disp_str; print $0 }' \
						cur_column=$(( $cur_day + 1 )) disp_str="$sub_name2")
					sed -i '' "${cur_row}s/^.*$/$sub_str/" $TEMP_SCHEDULE
					cur_row=$(( $cur_row + 1 ))
					sub_str=$(cat $TEMP_SCHEDULE | sed -n ${cur_row}p | \
						awk -F\| 'BEGIN{OFS="\|"} { $cur_column=disp_str; print $0 }' \
						cur_column=$(( $cur_day + 1 )) disp_str="$sub_name3")
					sed -i '' "${cur_row}s/^.*$/$sub_str/" $TEMP_SCHEDULE
				fi
				i=$(( $i + 1 ))
			done
		done
	done
}


DETECT_COLLISION() {
	if [ -e $TEMP_COLLISION ]; then
		rm $TEMP_COLLISION
	fi
	for cos_num in $(echo $TEMP_SELECTION);do
		cos_info=$( grep -w "^$cos_num" $COURSE_LIST | awk -F\" '{print $2}' ) # cos_info sample: 3IJK4B-EC325|Intro. to Network
		cos_name=$( echo $cos_info | awk -F\| '{print $2}' )	# cos_name sample: Intro. to Network
		cos_time_location=$( echo $cos_info | awk -F\| '{print $1}' )	# cos_time_location sample: 3IJK4B-EC325,5EF-EDB27
		sum_time=""
		for sub_time_location in $( echo $cos_time_location | tr "," " " );do # format: ${COURSE_TIME}-${CORSE_LOCATION}
			sub_time=$( echo $sub_time_location | awk -F\- '{print $1}' ) # sub_time sample: 3IJK4B
			sum_time=$sum_time$sub_time
		done	
		i=1
		expand_time=""
		while [ $i -le ${#sub_time} ]; do
			cur_char=$( echo $sub_time | cut -c$i  )
			expr 1 + $cur_char > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				cur_day=$cur_char
			else
				cur_word=$cur_char
				expand_time=$expand_time$cur_day$cur_char #expand_time sample: 3I3J3K4B
			fi
			i=$(( $i + 1 ))
		done
		echo "$expand_time|$cos_name" >> $TEMP_COLLISION
	done
	j=1
	while [ $j -le $(cat $TEMP_COLLISION | wc -l) ]; do
		str1=$( sed -n "${j}p" $TEMP_COLLISION )
		k=$(( $j + 1 ))
		while [ $k -le $(cat $TEMP_COLLISION | wc -l) ]; do
			str2=$( sed -n "${k}p" $TEMP_COLLISION )		
			COMPARE_TIME "$str1" "$str2"
			k=$(( $k + 1))
		done
		j=$(( $j + 1 ))
	done
}

COMPARE_TIME() {
	str1_time=$( echo "$1" | awk -F\| '{print $1}' )
	str1_name=$( echo "$1" | awk -F\| '{print $2}' )
	str2_time=$( echo "$2" | awk -F\| '{print $1}' )
	str2_name=$( echo "$2" | awk -F\| '{print $2}' )
	i=1
	while [ $i -le ${#str1_time} ];do
		basic_time=$( echo "$str1_time" | cut -c$i-$(($i+1)) ) # basic_time sample: 3I
		echo "$str2" | grep -q "$basic_time"
		if [ $? -eq 0 ];then
			COLLISION_STR=$COLLISION_STR"Time: $basic_time\nCourse Name: $str1_name vs. $str2_name\n\n"
			IS_COLLISION_HAPPENED=1
		fi
		i=$(( $i + 2))
	done
}


MAIN () {
	FILL_SCHEDULE
	if [ $IS_SIMPLE_TABLE -eq 1 ]; then
		cp $TEMP_SCHEDULE temp_simple_schedule.txt
		TEMP_SIMPLE_SCHEDULE="./temp_simple_schedule.txt"
		cat $TEMP_SCHEDULE | cut -c1-87 > $TEMP_SIMPLE_SCHEDULE
		CUR_FILE=$TEMP_SIMPLE_SCHEDULE
	else
		CUR_FILE=$TEMP_SCHEDULE
	fi
	dialog --extra-button --extra-label "Option" --help-button --help-label "Exit" --ok-label "Add Class" \
	       	--textbox $CUR_FILE 60 140
}

SUBMIT_SELECTION() {
	if [ $IS_COLLISION_HAPPENED -eq 1 ]; then
		dialog --title "COLLISION OCCURED" --msgbox "$COLLISION_STR" 30 100
		SHOW_COURSE_LIST
	else
		echo "$TEMP_SELECTION" > $SELECTED_COURSES
	fi
}

SHOW_COURSE_LIST() {
	# get selected courses from file system, and show them on the "selected courses" column
	if [ $IS_COLLISION_HAPPENED -eq 0 ]; then
		CUR_FILE=$( cat $SELECTED_COURSES )
	else
		CUR_FILE=$( echo  $TEMP_SELECTION )
		IS_COLLISION_HAPPENED=0
		COLLISION_STR=""
	fi
	
	for cos_num in $CUR_FILE; do
		#modify: off => on
		sed -i '' "${cos_num}s/off$/on/g" $COURSE_LIST
	done
	exec 3>&1
	TEMP_SELECTION=$(dialog --title "Add Class" --buildlist "Courses" 0 130 50 --file $COURSE_LIST 2>&1 1>&3)
	RETURN_VALUE=$?
	exec 3>&-
	sed -i '' 's/on$/off/g' $COURSE_LIST
	if [ $RETURN_VALUE -eq 0 ]; then
		DETECT_COLLISION
		SUBMIT_SELECTION
	fi
}

ON_OPTION_ACTIVED() {
	# traverse
	if [ $NAME_LOC -eq 0 ];then
		NAME_LOC=1
	else
		NAME_LOC=0
	fi
}

ON_SIMPLE_TABLE_ACTIVED() {
	if [ $IS_SIMPLE_TABLE -eq 0 ]; then
		IS_SIMPLE_TABLE=1
	else
		IS_SIMPLE_TABLE=0
	fi
}


ON_FREE_TIME_ACTIVED() {
	echo "Processing, please wait...."
	if [ -e $TEMP_CONTAINER ]; then
		rm -f $TEMP_CONTAINER
	fi
	for cos_num in $(cat $SELECTED_COURSES);do
		cos_info=$( grep -w "^$cos_num" $COURSE_LIST | awk -F\" '{print $2}' ) # cos_info sample: 3IJK4B-EC325|Intro. to Network
		cos_name=$( echo $cos_info | awk -F\| '{print $2}' )	# cos_name sample: Intro. to Network
		cos_time_location=$( echo $cos_info | awk -F\| '{print $1}' )	# cos_time_location sample: 3IJK4B-EC325,5EF-EDB27
		sum_time=""
		for sub_time_location in $( echo $cos_time_location | tr "," " " );do # format: ${COURSE_TIME}-${CORSE_LOCATION}
			sub_time=$( echo $sub_time_location | awk -F\- '{print $1}' ) # sub_time sample: 3IJK4B
			sum_time=$sum_time$sub_time
		done	
		i=1
		expand_time=""
		while [ $i -le ${#sub_time} ]; do
			cur_char=$( echo $sub_time | cut -c$i  )
			expr 1 + $cur_char > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				cur_day=$cur_char
			else
				cur_word=$cur_char
				expand_time=$expand_time$cur_day$cur_char #expand_time sample: 3I3J3K4B
			fi
			i=$(( $i + 1 ))
		done
		echo "$expand_time|$cos_name" >> $TEMP_CONTAINER
	done
	
	if [ -e $TEMP_COLLISION_ALL ]; then
		rm -f $TEMP_COLLISION_ALL
		COLLISION_STR_ALL=""
	fi
	p=1
	while [ $p -le $(cat $COURSE_LIST | wc -l) ];do
		cos_info=$( grep -w "^${p}" $COURSE_LIST | awk -F\" '{print $2}' ) # cos_info sample: 3IJK4B-EC325|Intro. to Network
		cos_name=$( echo $cos_info | awk -F\| '{print $2}' )	# cos_name sample: Intro. to Network
		cos_time_location=$( echo $cos_info | awk -F\| '{print $1}' )	# cos_time_location sample: 3IJK4B-EC325,5EF-EDB27
		sum_time=""
		for sub_time_location in $( echo $cos_time_location | tr "," " " );do # format: ${COURSE_TIME}-${CORSE_LOCATION}
			sub_time=$( echo $sub_time_location | awk -F\- '{print $1}' ) # sub_time sample: 3IJK4B
			sum_time=$sum_time$sub_time
		done	
		i=1
		expand_time=""
		while [ $i -le ${#sub_time} ]; do
			cur_char=$( echo $sub_time | cut -c$i  )
			expr 1 + $cur_char > /dev/null 2>&1
			if [ $? -eq 0 ]; then
				cur_day=$cur_char
			else
				cur_word=$cur_char
				expand_time=$expand_time$cur_day$cur_char #expand_time sample: 3I3J3K4B
			fi
			i=$(( $i + 1 ))
		done
		echo "$expand_time|$cos_name" >> $TEMP_COLLISION_ALL
		p=$(( $p + 1 ))
	done
	j=1
	while [ $j -le $(cat $TEMP_COLLISION_ALL | wc -l) ]; do
		str1=$( sed -n "${j}p" $TEMP_COLLISION_ALL )
		k=1
		IS_COLLISION_HAPPENED_ALL=0
		while [ $k -le $(cat $TEMP_CONTAINER | wc -l) ]; do
			str2=$( sed -n "${k}p" $TEMP_CONTAINER )		
			str1_time=$( echo "$str1" | awk -F\| '{print $1}' )
			str1_name=$( echo "$str1" | awk -F\| '{print $2}' )
			str2_time=$( echo "$str2" | awk -F\| '{print $1}' )
			str2_name=$( echo "$str2" | awk -F\| '{print $2}' )
			i=1
			while [ $i -le ${#str1_time} ];do
				basic_time=$( echo "$str1_time" | cut -c$i-$(($i+1)) ) # basic_time sample: 3I
				echo "$str2" | grep -q "$basic_time"
				if [ $? -eq 0 ];then
					IS_COLLISION_HAPPENED_ALL=1
				fi
			i=$(( $i + 2 ))
			done
			k=$(( $k + 1 ))
		done
		if [ $IS_COLLISION_HAPPENED_ALL -eq 0 ]; then
			COLLISION_STR_ALL=$COLLISION_STR_ALL"$( grep -w "^${j}" $COURSE_LIST | awk -F\" '{print $1 "  " $2}' )""\n"
		fi	
		j=$(( $j + 1 ))
	done 
	dialog --title "Course Free Time" --msgbox "$COLLISION_STR_ALL" 50 130
}

ON_SEARCH_ACTIVED() {
	exec 3>&1
	if [ $NAME_TIME_SEARCH -eq 0 ];then
		input_type="Course Name"
	else
		input_type="Course Time"
	fi
	input_str=$( dialog --title "Input Course Name" \
		--inputbox "Enter the ${input_type}:" 30 70 2>&1 1>&3 )
	exec 3>&-
	if [ $? -eq 0 ]; then
		i=1
		sum_str=""
		while [ $i -le $( cat $COURSE_LIST | wc -l ) ]; do
			sub_str=$( sed -n "${i}p" $COURSE_LIST | awk -F\" '{print $2}')
			if [ $NAME_TIME_SEARCH -eq 0 ];then
				search_content=$( echo $sub_str | awk -F\| '{print $2}' )
			else
				search_content=$( echo $sub_str | awk -F\| '{print $1}' )
			fi
			echo "$sub_str" | grep -q "$input_str"
			if [ $? -eq 0 ]; then
				sum_str=$sum_str$sub_str"\n"
			fi
			i=$(( $i + 1 ))
		done
	fi
	if [ ${#sum_str} -eq 0 ]; then
		sum_str="\"${input_str}\"Not Found."
	fi
	dialog --title "Search Result" --msgbox "$sum_str" 50 130
}

SHOW_OPTION() {
	if [ $IS_SIMPLE_TABLE -eq 1 ]; then
		hide_show="Show"
	else
		hide_show="Hide"
	fi
	if [ $NAME_LOC -eq 0 ]; then
		name_loc="Classroom"
	else
		name_loc="Course Name"
	fi
	exec 3>&1
	flag=$( dialog --title "Pick a choice" --menu "Choose one" 20 50 100 \
		1 "Show ${name_loc}" \
		2 "${hide_show} Extra Column" \
		3 "Course for free time" 2>&1 1>&3 \
		4 "Course searching(name based)" \
		5 "Course searching(time based)" )
	exec 3>&-
	case $flag in
		1) ON_OPTION_ACTIVED;;
		2) ON_SIMPLE_TABLE_ACTIVED;;
		3) ON_FREE_TIME_ACTIVED;;
		4) 	NAME_TIME_SEARCH=0
			ON_SEARCH_ACTIVED;;
		5) 	NAME_TIME_SEARCH=1
			ON_SEARCH_ACTIVED;;
	esac
}

# show main menu
while true; do
	MAIN
	case $? in
		0)  #Add Class
			SHOW_COURSE_LIST
			;;
		1)  #Exit
			rm -f $TEMP_SCHEDULE
			rm -f $TEMP_SIMPLE_SCHEDULE
			rm -f $TEMP_COLLISION
			rm -f $TEMP_COLLISION_ALL
			rm -f $TEMP_CONTAINER
			exit 0
			;;
		3)  #Option : show course name => show classroom
			SHOW_OPTION
			;;
	esac
done


