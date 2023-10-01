package ht.henrique.mazebank.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class DatabaseException extends BaseException{

    public DatabaseException(HttpStatus httpStatus, Integer errorCode, String message){
        super(httpStatus, errorCode, message);
    }
}
