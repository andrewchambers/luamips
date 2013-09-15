
while [ true ]
do
	
	if ! bash next.sh ; then
		echo "error failed to generate next case!"
		exit 1
	fi
	
		
	
	if bash interesting.sh ; then
		echo "found interesting file..."
		exit 0
	fi
done
