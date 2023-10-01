package ht.henrique.mazebank.model.fetch;

import ht.henrique.mazebank.model.Response;
import lombok.Data;
import org.bson.Document;
import org.bson.types.Decimal128;
import org.bson.types.ObjectId;

import java.math.BigDecimal;
import java.text.DecimalFormat;

@Data
public class FetchUserResponse implements Response {
    private String uid;
    private String userName;
    private String userEmail;
    private String userCreateDate;
    private Decimal128 userBalance;

}
