package ht.henrique.mazebank.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public class ControllerException extends Exception {

    private HttpStatus httpStatus;
    private String message;
    private Integer errorCode;

    public ControllerException(HttpStatus httpStatus, Integer errorCode, String message){
        this.httpStatus = httpStatus;
        this.message = message;
        this.errorCode = errorCode;
    }
}
