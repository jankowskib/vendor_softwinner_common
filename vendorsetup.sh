#
# Copyright (C) 2015 Bartosz Jankowski
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#!/bin/bash

function pack()
{
	echo "Packing image..."
	if [ "$(get_build_var PRODUCT_MANUFACTURER)" = "softwinner" ]; then	
	
	if [ "$1" = "-d" -o "$2" = "-d" ]; then
		echo "Redirecting UART to SD MMC slot"
		DEBUG="card0";
	else 
		DEBUG="uart0"
	fi
	
	if [ "$1" = "-s" -o "$2" = "-s" ]; then
		echo "Appling signature to the image"
		SIGMODE="sig";
	else 
		SIGMODE="none"
	fi
	croot
	cd vendor/softwinner/common/package
	CRANE_IMAGE_OUT=$OUT LICHEE_OUT=$(gettop) ./pack -c sun6i -p android -b $(get_build_var TARGET_DEVICE) -d ${DEBUG} -s ${SIGMODE}
	croot
	else
			echo "Only usable on Allwinners!"
	fi
}
