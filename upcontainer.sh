docker container run -it\
    --mount type=bind,src=$(pwd)/src,dst=/nim-image-library/src\
    --mount type=bind,src=$(pwd)/bin,dst=/nim-image-library/bin\
    --mount type=bind,src=$(pwd)/sample,dst=/nim-image-library/sample\
    nim-image-library:latest
