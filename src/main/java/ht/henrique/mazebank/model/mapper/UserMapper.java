package ht.henrique.mazebank.model.mapper;


import ht.henrique.mazebank.model.create.CreateRequest;
import ht.henrique.mazebank.model.database.User;
import ht.henrique.mazebank.model.fetch.FetchUserResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Mappings;

@Mapper(componentModel = "spring")
public interface UserMapper {

    @Mappings({
            @Mapping(source = "create.username", target = "_userName"),
            @Mapping(source = "create.useremail", target = "_userEmail"),
            @Mapping(source = "create.userpass", target = "_userPass")
    })
    User createToUser(CreateRequest create);

    @Mappings({
            @Mapping(source = "user._id", target = "uid"),
            @Mapping(source = "user._userName", target = "userName"),
            @Mapping(source = "user._userEmail", target = "userEmail"),
            @Mapping(source = "user._userCreatedAt", target = "userCreateDate"),
            @Mapping(source = "user._userBalance", target = "userBalance")
    })
    FetchUserResponse userToFetchUser(User user);
}
