package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.type.ReturnCode;
import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class BaseException extends Exception{

    private final ReturnCode returnCode;
    private final String message;

    public BaseException(ReturnCode errorCode, String message){
        this.returnCode = errorCode;
        this.message = message;
    }

}
