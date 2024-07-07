package ht.henrique.mazebank.model.type;

import lombok.Getter;
import org.springframework.http.HttpStatus;

@Getter
public enum ReturnCode {

    SUCCESS("200000", HttpStatus.OK),
    CREATE_SUCCESS("201000", HttpStatus.CREATED),
    INVALID_PARAMETERS("400000", HttpStatus.BAD_REQUEST),
    NOT_FOUND("404000", HttpStatus.NOT_FOUND),
    USER_ALREADY_EXISTS("409000", HttpStatus.CONFLICT),
    INTERNAL_SERVER_ERROR("500000", HttpStatus.INTERNAL_SERVER_ERROR);

    private final String code;
    private final HttpStatus httpStatus;

    ReturnCode(String code, HttpStatus httpStatus){
        this.code = code;
        this.httpStatus = httpStatus;
    }
}
