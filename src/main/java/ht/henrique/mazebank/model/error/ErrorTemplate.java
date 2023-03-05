package ht.henrique.mazebank.model.error;

import lombok.Data;

@Data
public class ErrorTemplate {

    private Integer errorCode;
    private String errorMessage;
    private String timeStamp;
}
