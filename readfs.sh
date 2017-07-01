#!/bin/sh
## readfs.sh 0.01 ##



## programexit
## 
programexit()
{
	case $1 in
		0) # no arguments
			echo "usage: `basename $0` device"
			echo "  example: `basename $0` /dev/sd1c"
			;;
		1) # file does not exist
			echo "file ${devicename} does not exist"
			;;
		2) # read_partitions without arguments
			echo "read_partitions without arguments"
			;;
		*) # general case?
			;;
	esac

	if [ ! -z ${cleanfiles} ]; then
		# debug
		echo " ** delete ${cleanfiles}"
		# delete temp files
		rm -f ${cleanfiles}
	fi

	exit
}






## read_partitions
##   device: devicename
##   sector: arg1
##   
##   return: list of partitions
##           each line is:
##           num boot type startsect size
read_partitions()
{

	# check arguments
	sect_add[${lvl}]=$1
	### debug ###
	#echo "*** read_partition ${lvl}: sect_add=${sect_add[${lvl}]} " >> read.log
	if [ -z ${sect_add[${lvl}]} ]; then
		programexit 2
	fi


	sectfile[${lvl}]=`mktemp`
	### debug ###
	#echo "*** read_partition ${lvl}: sectfile=${sectfile[${lvl}]} " >> read.log

	# for future clean
	#cleanfiles="${cleanfiles} ${sectfile[${lvl}]}"


	## copy sector
	dd if=${devicename} of=${sectfile[${lvl}]} bs=512 count=1 skip=$((0x${sect_add[${lvl}]})) 2>/dev/null
	if [ "$?" -ne 0 ]; then
		### debug ###
		#echo "*** read_partition ${lvl}: dd error" >> read.log
		return
	fi



	## check signature
	sig[${lvl}]=`xxd -g 2 -l 2 -s 0x1fe ${sectfile[${lvl}]} | awk '{print $2}'`
	if [ ${sig[${lvl}]} != '55aa' ]; then
		return
	fi
	### debug ###
	#echo "*** read_partition ${lvl}: sig=${sig[${lvl}]} " >> read.log


	## loop for every partition

	offset[${lvl}]=$((0x1be))
	for pnum[${lvl}] in 0 1 2 3; do
		### debug ###
		#echo "*** read_partition ${lvl}: pnum=${pnum[${lvl}]} " >> read.log
		type[${lvl}]=`xxd -g 1 -l 1 -s $((${offset[${lvl}]}+0x4)) ${sectfile[${lvl}]} | awk '{print $2}'`
		### debug ###
		#echo "*** read_partition ${lvl}: type=${type[${lvl}]} " >> read.log
		# check if partition is valid
		case ${type[${lvl}]} in
			'00') # invalid
				;;
			'05') # extended partition
				# get start of partition
				start_tmp=`xxd -e -g 4 -l 4 -s $((${offset[${lvl}]}+0x8))  ${sectfile[${lvl}]} | awk '{print $2}'`
				start_tmp=`printf "%x" $(( 0x${start_tmp} + 0x${sect_add[${lvl}]} ))`
				lvl=`expr ${lvl} + 1`
				read_partitions ${start_tmp}
				lvl=`expr ${lvl} - 1`
				;;
			*) # valid partition
				# print partition number
				echo -n ${global_pnum}
				# print boot
				echo -n " `xxd -g 1 -l 1 -s ${offset[${lvl}]}  ${sectfile[${lvl}]} | awk '{print $2}'`"
				# print type
				echo -n " ${type[${lvl}]}"
				# print start
				start_tmp=`xxd -e -g 4 -l 4 -s $((${offset[${lvl}]}+0x8))  ${sectfile[${lvl}]} | awk '{print $2}'`
				start_tmp=`printf "%x" $(( 0x${start_tmp} + 0x${sect_add[${lvl}]} ))`
				echo -n " ${start_tmp}"
				# print size
				echo " `xxd -e -g 4 -l 4 -s $((${offset[${lvl}]}+0xc))  ${sectfile[${lvl}]} | awk '{print $2}'`"
				global_pnum=$((${global_pnum} + 1))
				;;
		esac
		offset[${lvl}]=$((${offset[${lvl}]} + 0x10))
	done
			
	



}



## script start here ##

## debug ##
#rm -f "read.log"


## checking arguments ##
if [ -z "$1" ]; then
	programexit '0'
fi

# get devicename from argument 1
devicename=$1

### debug ###
#echo " ** devicename=${devicename}" >> read.log

## checking if that file exists ##
if [ ! -a "${devicename}" ]; then
	programexit 1
fi


## read partitions ##
lvl=0
global_pnum=0
partition_list=`read_partitions 0`



echo "${partition_list}"







