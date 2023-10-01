package ht.henrique.mazebank.exception;

import ht.henrique.mazebank.model.error.ErrorTemplate;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.sql.Timestamp;
import java.util.Date;

@ControllerAdvice
@Slf4j
public class HandleException {

    @ExceptionHandler(value = {ControllerException.class})
    public ResponseEntity<ErrorTemplate> handlerException(ControllerException exception){
        return buildResponse(exception);
    }

    @ExceptionHandler(value = {DatabaseException.class})
    public ResponseEntity<ErrorTemplate> handlerException(DatabaseException exception){
        return buildResponse(exception);
    }


    public ResponseEntity<ErrorTemplate> buildResponse(BaseException baseException) {
        Date date = new Date();
        ErrorTemplate errorTemplate = ErrorTemplate.builder()
                .errorCode(baseException.getErrorCode())
                .errorMessage(baseException.getMessage())
                .timeStamp(new Timestamp(date.getTime()).toString())
                .build();
        log.info(errorTemplate.toString());
        return ResponseEntity.status(baseException.getHttpStatus()).body(errorTemplate);
    }
}
