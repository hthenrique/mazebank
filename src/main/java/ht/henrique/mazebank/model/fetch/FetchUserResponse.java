package ht.henrique.mazebank.model.fetch;

import ht.henrique.mazebank.model.Response;
import jakarta.persistence.Column;
import lombok.Data;

import java.math.BigDecimal;
import java.text.DecimalFormat;

@Data
public class FetchUserResponse implements Response {
    private Integer uid;
    private String userName;
    private BigDecimal userBalance;
    private String userEmail;
}
