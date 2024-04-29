#!/bin/bash


## script to get nas storage usage and report it

	# nas-ru1.bu.edu/CNC
	# this is where scans are saved off scanner
	# this is where scans are sorted & zipped
		# Get disk usage
		usage=`df -h /cnc | column -t`
		date=`date -I`

		# Print to nas_check.log
		total=`echo $usage | awk '{print $9}'`
		current=`echo $usage | awk '{print $10}'`
		avail=`echo $usage | awk '{print $11}'`
		perc=`echo $usage | awk '{print $12}'`
		echo $date $current $avail $perc $total >> CILSE-CNC
		echo "nas-ru1/CNC USAGE: "$current "/" $total "DATE:" $date

	# nas1:/ou/clice-cnc
	# this is where the XNAT APP and Images are saved
	# this is currently in production for xnat.bu.edu
		# Get disk usage
                usage=`df -h /data-ro_1 | column -t`
                date=`date -I`

                # Print to nas_check.log
                total=`echo $usage | awk '{print $9}'`
                current=`echo $usage | awk '{print $10}'`
                avail=`echo $usage | awk '{print $11}'`
                perc=`echo $usage | awk '{print $12}'`
                echo $date $current $avail $perc $total >> CILSE-CNC
                echo "nas1:/ou/cilse-cnc USAGE: "$current "/" $total "DATE:" $date

        # nas2:/ou/clice-cnc
        # this is an extra backup that is unused
	# actually not sure what utility this space serves
        # this is currently in production for xnat.bu.edu
                # Get disk usage
                usage=`df -h /data-ro_2 | column -t`
                date=`date -I`

                # Print to nas_check.log
                total=`echo $usage | awk '{print $9}'`
                current=`echo $usage | awk '{print $10}'`
                avail=`echo $usage | awk '{print $11}'`
                perc=`echo $usage | awk '{print $12}'`
                echo $date $current $avail $perc $total >> CILSE-CNC
                echo "nas2:/ou/cilse-cnc USAGE: "$current "/" $total "DATE:" $date

