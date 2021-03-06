#!/bin/sh
# .../DockerManager/update.sh
# Scrip to recursively update docker images
# Script needs directory to work with.
# If not provided, directory '.../DockerManager/dockerfiles' is assumed

# include some functions
. "$(dirname $0)/shared_code.sh"

parse_target_name $@

# If folder was not specified, we'll fall back to default.
if ! target_exists $TARGET_DIR_NAME_FULL ; then
        # there's no such directory
        echo "Error: could not find $TARGET_DIR_NAME_FULL";
        exit 1;
                        
fi

if [[ -n "$1" ]]; then # Target is specified, do some building
	# TODO: check if target exists
	if [[ ! -f "${TARGET_DIR_NAME_FULL}/Dockerfile" ]] ; then
		echo "Error: could not find ${TARGET_DIR_NAME_FULL}/Dockerfile";
		exit 1;
	fi # As of now, we're sure that target exists
	
	# Build
	if docker build --tag="$(untested_image_name $TARGET)" $TARGET_DIR_NAME_FULL ; 
	then
		# Build was a success, let's run some tests and update if they're  OK
#		echo building succeded!;
		if docker run "$(untested_image_name $TARGET)" /container-tests/main ; then
			echo "$TARGET has passed its tests, making it available as $(tested_image_name $TARGET)";
			# TODO: this is a critical section
			# correct interaction with image dispenser is needed
			docker tag -f "$(untested_image_name $TARGET)" "$(tested_image_name $TARGET)"
			docker rmi "$(untested_image_name $TARGET)"
		else
			echo "Error: $TARGET have failed some of tests!";
		fi
	else
		# Build failed. Children may need updating anyway, so we continue.
		echo "Error: Building $TARGET failed!"
	fi
fi

# Let's process dependants, in parallel.
for child in $(get_dependants $TARGET_DIR_NAME_FULL); do
	# remove slash from beginning if any
	CHILD_TARGET_NAME=$(echo "$TARGET/$child" | sed 's/^\///' )
	$0 $CHILD_TARGET_NAME &
done

#TODO: wait for child processes
