docker run -it --rm --privileged --gpus all -e NVIDIA_DISABLE_REQUIRE=1 -e NVIDIA_DRIVER_CAPABILITIES=all -e CUDA_VISIBLE_DEVICES=7 \
	-v /data:/work \
	-p 9000:80 -p 9080:8080 -p 9443:443 \
	-p 9200:9200 -p 9300:9300 \ #elastic search
	-p 5601:5601 \ #kibana
       	--entrypoint "/bin/bash" \
       	--name container_example models-service:20ae71f
